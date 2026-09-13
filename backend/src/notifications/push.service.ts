import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { DeviceToken } from './entities/device-token.entity';
import { User } from '../users/entities/user.entity';

export interface PushPayload {
  title: string;
  body?: string;
  /** Datos para que la app sepa qué abrir al tocar la notificación. */
  data?: Record<string, string>;
}

/** Errores de FCM que indican que el token ya no sirve y hay que borrarlo. */
const DEAD_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/**
 * Notificaciones push al móvil con Firebase Cloud Messaging.
 * Se activa con FIREBASE_SERVICE_ACCOUNT: el JSON de la cuenta de servicio
 * (tal cual o en base64). Sin esa variable no se envía nada.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private app: App | null | undefined;

  constructor(
    @InjectRepository(DeviceToken)
    private readonly tokensRepo: Repository<DeviceToken>,
  ) {}

  /** Lee la cuenta de servicio aceptando JSON directo o codificado en base64. */
  static parseServiceAccount(raw: string | undefined): Record<string, any> | null {
    const value = raw?.trim();
    if (!value) return null;
    const candidates = [value];
    if (!value.startsWith('{')) candidates.push(Buffer.from(value, 'base64').toString('utf8'));
    for (const candidate of candidates) {
      try {
        const parsed = JSON.parse(candidate);
        if (parsed && typeof parsed === 'object' && parsed.private_key && parsed.client_email) return parsed;
      } catch {
        // probamos el siguiente formato
      }
    }
    return null;
  }

  private getApp(): App | null {
    if (this.app !== undefined) return this.app;
    const account = PushService.parseServiceAccount(process.env.FIREBASE_SERVICE_ACCOUNT);
    if (!account) {
      if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        this.logger.error('FIREBASE_SERVICE_ACCOUNT no es un JSON de cuenta de servicio válido');
      }
      this.app = null;
      return null;
    }
    try {
      this.app = getApps()[0] ?? initializeApp({ credential: cert(account as any) });
    } catch (e) {
      this.logger.error(`No se pudo iniciar Firebase: ${(e as Error).message}`);
      this.app = null;
    }
    return this.app;
  }

  get isEnabled(): boolean {
    return this.getApp() !== null;
  }

  async registerDevice(userId: number, token: string, platform: string) {
    const clean = token.trim();
    const safePlatform = platform === 'ios' ? 'ios' : 'android';
    const existing = await this.tokensRepo.findOne({ where: { token: clean }, relations: { user: true } });
    if (existing) {
      // El mismo móvil puede cambiar de cuenta: el token pasa al usuario actual
      existing.user = { id: userId } as User;
      existing.platform = safePlatform;
      await this.tokensRepo.save(existing);
    } else {
      await this.tokensRepo.save(
        this.tokensRepo.create({ user: { id: userId } as User, token: clean, platform: safePlatform }),
      );
    }
    return { registered: true };
  }

  async unregisterDevice(userId: number, token: string) {
    await this.tokensRepo.delete({ token: token.trim(), user: { id: userId } } as any);
    return { removed: true };
  }

  /** Envía la notificación a todos los móviles de esos usuarios. No lanza errores. */
  async sendToUsers(userIds: number[], payload: PushPayload) {
    if (userIds.length === 0) return;
    const app = this.getApp();
    if (!app) return;
    try {
      const devices = await this.tokensRepo.find({ where: { user: { id: In(userIds) } } as any });
      if (devices.length === 0) return;
      const tokens = devices.map((d) => d.token);

      const result = await getMessaging(app).sendEachForMulticast({
        tokens,
        notification: { title: payload.title, body: payload.body },
        data: payload.data,
        android: { priority: 'high', notification: { sound: 'default' } },
        apns: { payload: { aps: { sound: 'default' } } },
      });

      const dead = result.responses
        .map((r, i) => (!r.success && r.error && DEAD_TOKEN_ERRORS.has(r.error.code) ? tokens[i] : null))
        .filter((t): t is string => t !== null);
      if (dead.length) await this.tokensRepo.delete({ token: In(dead) });
      if (result.failureCount > dead.length) {
        this.logger.warn(`FCM: ${result.failureCount - dead.length} envíos fallidos`);
      }
    } catch (e) {
      this.logger.error(`Error enviando push: ${(e as Error).message}`);
    }
  }
}
