import { Controller, Get, Param, Res, NotFoundException, BadRequestException } from '@nestjs/common';
import type { Response } from 'express';
import { createReadStream, existsSync, statSync } from 'fs';
import { join, extname, basename } from 'path';
import { AVATARS_DIR } from './users.controller';

const MIME_BY_EXT: Record<string, string> = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
};

/**
 * Sirve los avatares subidos.
 *
 * Se hace con un controlador propio en lugar de `ServeStaticModule` porque
 * ese paquete exige NestJS 12 y el proyecto va con la 11. Además así
 * controlamos las cabeceras y validamos el nombre de archivo.
 */
@Controller('uploads/avatars')
export class UploadsController {
  @Get(':filename')
  serveAvatar(@Param('filename') filename: string, @Res() res: Response) {
    // `basename` neutraliza cualquier intento de path traversal (../../etc)
    const safeName = basename(filename);
    if (safeName !== filename || safeName.includes('\0')) {
      throw new BadRequestException('Nombre de archivo no válido');
    }

    const ext = extname(safeName).toLowerCase();
    const contentType = MIME_BY_EXT[ext];
    if (!contentType) {
      throw new BadRequestException('Formato no admitido');
    }

    const filePath = join(AVATARS_DIR, safeName);
    if (!existsSync(filePath) || !statSync(filePath).isFile()) {
      throw new NotFoundException('Avatar no encontrado');
    }

    res.set({
      'Content-Type': contentType,
      // El nombre incluye un hash aleatorio, así que el contenido es inmutable
      'Cache-Control': 'public, max-age=604800, immutable',
      'Access-Control-Allow-Origin': '*',
      'Cross-Origin-Resource-Policy': 'cross-origin',
    });

    createReadStream(filePath).pipe(res);
  }
}
