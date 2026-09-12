import { Controller, Get, Post, UseGuards, Req, Res, Logger } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  private readonly logger = new Logger(AuthController.name);

  constructor(private readonly authService: AuthService) {}

  @Get('google')
  @UseGuards(AuthGuard('google'))
  async googleAuth(@Req() req) {}

  @Get('google/callback')
  @UseGuards(AuthGuard('google'))
  async googleAuthRedirect(@Req() req, @Res() res) {
    try {
      if (!req.user) {
        throw new Error('No user from google');
      }
      const result = await this.authService.validateGoogleUser(req.user);
      const token = result.access_token;
      const user = JSON.stringify(result.user);
      
      const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:8100';
      return res.redirect(`${frontendUrl}/tabs/callback?token=${token}&user=${encodeURIComponent(user)}`);
    } catch (error) {
      this.logger.error(`Error en google callback: ${error.message}`);
      const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:8100';
      return res.redirect(`${frontendUrl}/login?error=auth_failed`);
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
