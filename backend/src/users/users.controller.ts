import {
  Controller,
  Get,
  Body,
  Patch,
  Post,
  Delete,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Req,
  BadRequestException,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { randomBytes } from 'crypto';
import { existsSync, mkdirSync, unlinkSync } from 'fs';
import { UsersService } from './users.service';

/** Carpeta donde se guardan los avatares subidos. */
export const AVATARS_DIR = join(process.cwd(), 'uploads', 'avatars');

const ALLOWED_MIME = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const MAX_AVATAR_BYTES = 5 * 1024 * 1024; // 5 MB

@Controller('users')
@UseGuards(AuthGuard('jwt'))
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('profile')
  async getProfile(@Req() req) {
    return this.usersService.getProfile(req.user.id);
  }

  @Patch('profile')
  async updateProfile(
    @Req() req,
    @Body() body: { firstName?: string; lastName?: string; bio?: string; favoriteGenre?: string; picture?: string; readingGoal?: number },
  ) {
    return this.usersService.updateProfile(req.user.id, body);
  }

  /**
   * Sube una imagen de avatar y la asocia al usuario.
   * Devuelve el perfil actualizado con la nueva URL en `picture`.
   */
  @Post('avatar')
  @UseInterceptors(
    FileInterceptor('avatar', {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          if (!existsSync(AVATARS_DIR)) {
            mkdirSync(AVATARS_DIR, { recursive: true });
          }
          cb(null, AVATARS_DIR);
        },
        filename: (req: any, file, cb) => {
          // Nombre impredecible para no exponer ids ni permitir sobrescrituras
          const unique = `${req.user?.id ?? 'u'}_${Date.now()}_${randomBytes(6).toString('hex')}`;
          cb(null, `${unique}${extname(file.originalname).toLowerCase() || '.jpg'}`);
        },
      }),
      limits: { fileSize: MAX_AVATAR_BYTES },
      fileFilter: (_req, file, cb) => {
        if (!ALLOWED_MIME.includes(file.mimetype)) {
          return cb(new BadRequestException('Formato no admitido. Usa JPG, PNG, WEBP o GIF.'), false);
        }
        cb(null, true);
      },
    }),
  )
  async uploadAvatar(@Req() req, @UploadedFile() file: Express.Multer.File) {
    if (!file) throw new BadRequestException('No se recibió ninguna imagen');

    // Si tenía un avatar subido previamente, lo borramos para no acumular
    const current = await this.usersService.getProfile(req.user.id);
    this.removePreviousAvatar(current.picture);

    const publicUrl = `/uploads/avatars/${file.filename}`;
    return this.usersService.updateProfile(req.user.id, { picture: publicUrl });
  }

  /** Quita el avatar actual y vuelve a la inicial del nombre. */
  @Delete('avatar')
  async removeAvatar(@Req() req) {
    const current = await this.usersService.getProfile(req.user.id);
    this.removePreviousAvatar(current.picture);
    return this.usersService.updateProfile(req.user.id, { picture: null as any });
  }

  private removePreviousAvatar(picture?: string | null) {
    if (!picture || !picture.startsWith('/uploads/avatars/')) return;
    try {
      const filePath = join(process.cwd(), picture.replace(/^\//, ''));
      if (existsSync(filePath)) unlinkSync(filePath);
    } catch {
      // Si no se puede borrar el anterior no bloqueamos la subida del nuevo
    }
  }
}
