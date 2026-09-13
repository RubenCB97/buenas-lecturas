import {
  BadRequestException,
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { SearchService } from './search.service';
import { COVER_MIME_TYPES, CoverRecognitionService } from './cover-recognition.service';

@Controller('search')
export class SearchController {
  constructor(
    private readonly searchService: SearchService,
    private readonly coverRecognition: CoverRecognitionService,
  ) {}

  /** Indica a la app si puede ofrecer el reconocimiento por foto. */
  @Get('cover/enabled')
  coverEnabled() {
    return { enabled: this.coverRecognition.isEnabled };
  }

  /** Reconoce un libro a partir de una foto de la portada (campo `image`). */
  @Post('cover')
  @UseGuards(AuthGuard('jwt'))
  @UseInterceptors(
    FileInterceptor('image', {
      storage: memoryStorage(),
      // Claude admite imágenes de hasta 5 MB
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  async recognizeCover(@UploadedFile() file: Express.Multer.File) {
    if (!file?.buffer?.length) throw new BadRequestException('No se recibió ninguna imagen');
    const mime = CoverRecognitionService.sniffMime(file.buffer) ?? file.mimetype;
    if (!COVER_MIME_TYPES.includes(mime as any)) {
      throw new BadRequestException('Formato de imagen no soportado (usa JPG, PNG o WebP)');
    }
    return this.coverRecognition.recognize(file.buffer, mime);
  }

  @Get()
  async search(@Query('q') query: string) {
    if (!query) return [];
    return this.searchService.searchBooks(query);
  }

  // Libros similares al detalle actual (estilo Goodreads "Readers also enjoyed")
  @Get('similar/:googleId')
  async similar(
    @Param('googleId') googleId: string,
    @Query('category') category?: string,
    @Query('author') author?: string,
  ) {
    return this.searchService.findSimilarBooks(googleId, category, author);
  }

  /**
   * Busca un libro por ISBN (lo usa el escáner de código de barras).
   * 400 si el ISBN no es válido; 404 si no aparece en ningún catálogo.
   */
  @Get('isbn/:isbn')
  async byIsbn(@Param('isbn') raw: string) {
    const isbn = SearchService.normalizeIsbn(raw);
    if (!isbn) throw new BadRequestException('El código no es un ISBN válido');
    const book = await this.searchService.lookupByIsbn(isbn);
    if (!book) throw new NotFoundException('No hemos encontrado ningún libro con ese ISBN');
    return book;
  }

  /**
   * Lanzamientos recientes: este mes, o los últimos 3/6 meses si aún hay pocos
   * catalogados. `windowMonths` indica qué ventana se usó.
   */
  @Get('recent-releases')
  async recentReleases(@Query('region') region?: string) {
    return this.searchService.findRecentReleases((region ?? '').toUpperCase() === 'ES' ? 'ES' : 'GLOBAL');
  }

  /**
   * Novedades de un año, paginadas.
   * region: ES (ediciones en español) | GLOBAL
   * sort:   readinglog (más leídos) | new (más recientes)
   */
  @Get('new-releases')
  async newReleases(
    @Query('year') year?: string,
    @Query('region') region?: string,
    @Query('sort') sort?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const raw = (region ?? 'GLOBAL').toUpperCase();
    const safeRegion: 'ES' | 'GLOBAL' = raw === 'ES' ? 'ES' : 'GLOBAL';
    const safeSort: 'readinglog' | 'new' = sort === 'new' ? 'new' : 'readinglog';

    return this.searchService.findNewReleases(
      year ? +year : undefined,
      safeRegion,
      safeSort,
      page ? +page : 1,
      limit ? +limit : 24,
    );
  }

  /**
   * Tendencias literarias reales por ámbito.
   * region: ES (literatura hispana) | GLOBAL (todo el mundo)
   * period: daily | weekly | monthly | yearly
   */
  @Get('trending')
  async trending(
    @Query('region') region?: string,
    @Query('period') period?: string,
  ) {
    const raw = (region ?? 'ES').toUpperCase();
    // 'US' se mantiene como alias de GLOBAL por compatibilidad
    const safeRegion: 'ES' | 'GLOBAL' = raw === 'GLOBAL' || raw === 'US' ? 'GLOBAL' : 'ES';
    const allowedPeriods = ['daily', 'weekly', 'monthly', 'yearly'] as const;
    const safePeriod = allowedPeriods.includes(period as any)
      ? (period as (typeof allowedPeriods)[number])
      : 'weekly';
    return this.searchService.findTrending(safeRegion, safePeriod);
  }

  // Libros de la misma saga/serie que uno dado
  @Get('series')
  async series(
    @Query('title') title: string,
    @Query('author') author?: string,
    @Query('googleId') googleId?: string,
  ) {
    if (!title || title.trim().length === 0) return [];
    return this.searchService.findBooksInSeries({
      title,
      authors: author ? [author] : [],
      googleId,
    });
  }
}
