import {
  BadRequestException,
  Controller,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { extname } from 'path';
import { GoodreadsImportService } from './goodreads-import.service';

const CSV_MIME = ['text/csv', 'text/plain', 'application/csv', 'application/vnd.ms-excel', 'application/octet-stream'];

@Controller('import')
@UseGuards(AuthGuard('jwt'))
export class ImportController {
  constructor(private readonly goodreads: GoodreadsImportService) {}

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
