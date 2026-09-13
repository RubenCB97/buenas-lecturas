import { Controller, Get, Param, Query } from '@nestjs/common';
import { SearchService } from './search.service';

@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

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
