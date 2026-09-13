import { Controller, Get, Post, UseGuards, Req, Res, Logger } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { buildAuthRedirect, GoogleAuthGuard } from './google-auth.guard';

@Controller('auth')
export class AuthController {
  private readonly logger = new Logger(AuthController.name);

  constructor(private readonly authService: AuthService) {}

  /** Inicia el login. La app móvil añade `?platform=app`. */
  @Get('google')
  @UseGuards(GoogleAuthGuard)
  async googleAuth(@Req() req) {}

  @Get('google/callback')
  @UseGuards(AuthGuard('google'))
  async googleAuthRedirect(@Req() req, @Res() res) {
    const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:8100';
    const state = req.query?.state;
    try {
      if (!req.user) {
        throw new Error('No user from google');
      }
      const result = await this.authService.validateGoogleUser(req.user);
      return res.redirect(
        buildAuthRedirect(state, frontendUrl, { token: result.access_token, user: JSON.stringify(result.user) }),
      );
    } catch (error) {
      this.logger.error(`Error en google callback: ${error.message}`);
      return res.redirect(buildAuthRedirect(state, frontendUrl, null));
    }
  }

  @Get('dev-login')
  async devLogin() {
    return this.authService.loginDevUser();
  }

  @Post('dev-login')
  async devLoginPost() {
    return this.authService.loginDevUser();
  }
}
