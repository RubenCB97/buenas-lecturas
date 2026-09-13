import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/** Esquema con el que el servidor devuelve la sesión a la app móvil. */
export const APP_CALLBACK_SCHEME = 'buenaslecturas';

/**
 * Login con Google que recuerda desde dónde se inició: `?platform=app` viaja
 * en el parámetro `state` de OAuth y vuelve en el callback, para redirigir a
 * la app móvil en vez de a la web.
 */
@Injectable()
export class GoogleAuthGuard extends AuthGuard('google') {
  getAuthenticateOptions(context: ExecutionContext) {
    const req = context.switchToHttp().getRequest();
    return { state: req.query?.platform === 'app' ? 'app' : 'web' };
  }
}

/** URL a la que volver tras el login, según dónde se inició. */
export function buildAuthRedirect(
  state: unknown,
  frontendUrl: string,
  result: { token: string; user: string } | null,
): string {
  const params = result
    ? `token=${encodeURIComponent(result.token)}&user=${encodeURIComponent(result.user)}`
    : 'error=auth_failed';
  if (state === 'app') return `${APP_CALLBACK_SCHEME}://auth?${params}`;
  return result ? `${frontendUrl}/tabs/callback?${params}` : `${frontendUrl}/login?${params}`;
}
