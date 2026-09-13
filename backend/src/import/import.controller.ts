import {
  BadRequestException,
  Controller,
  Get,
  Post,
  Res,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { memoryStorage } from 'multer';
import { extname } from 'path';
import { GoodreadsImportService } from './goodreads-import.service';

const CSV_MIME = ['text/csv', 'text/plain', 'application/csv', 'application/vnd.ms-excel', 'application/octet-stream'];

@Controller('import')
@UseGuards(AuthGuard('jwt'))
export class ImportController {
  constructor(private readonly goodreads: GoodreadsImportService) {}

  /**
   * Descarga la biblioteca en el formato CSV de Goodreads: sirve de copia de
   * seguridad, para volver a importarla o para subirla a Goodreads.
   */
  @Get('export/goodreads')
  async exportGoodreads(@Req() req, @Res() res: Response) {
    const { csv } = await this.goodreads.exportCsv(req.user.id);
    const date = new Date().toISOString().slice(0, 10);
    res.set({
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="buenaslecturas_biblioteca_${date}.csv"`,
      'Cache-Control': 'no-store',
    });
    // BOM para que Excel reconozca las tildes
    res.send('\uFEFF' + csv);
  }

  /** Importa el CSV exportado desde Goodreads (campo `file`). */
  @Post('goodreads')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 15 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        const isCsv = extname(file.originalname).toLowerCase() === '.csv' || CSV_MIME.includes(file.mimetype);
        if (!isCsv) return cb(new BadRequestException('Sube el archivo .csv que exporta Goodreads'), false);
        cb(null, true);
      },
    }),
  )
  async importGoodreads(@Req() req, @UploadedFile() file: Express.Multer.File) {
    if (!file?.buffer?.length) throw new BadRequestException('No se recibió ningún archivo');
    return this.goodreads.importCsv(req.user.id, file.buffer.toString('utf8'));
  }
}
