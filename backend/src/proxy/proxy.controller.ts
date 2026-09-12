import { Controller, Get, Query, Res, Logger } from '@nestjs/common';
import type { Response } from 'express';
import { createHash } from 'crypto';

interface CachedImage {
  buffer: Buffer;
  contentType: string;
  etag: string;
  expiresAt: number;
}

@Controller('proxy')
export class ProxyController {
  private readonly logger = new Logger(ProxyController.name);

  /**
   * Caché en memoria de portadas. Evita repegarle a Google en cada navegación
   * (que acaba devolviendo 429/503 y dejando huecos en la UI).
   */
  private static readonly cache = new Map<string, CachedImage>();
  private static readonly MAX_ENTRIES = 500;
  private static readonly TTL_MS = 1000 * 60 * 60 * 12; // 12 h

  /** Por debajo de esto asumimos que es un pixel transparente, no una portada. */
  private static readonly MIN_IMAGE_BYTES = 1000;

  private static readonly ALLOWED_HOSTS = [
    'books.google.com',
    'books.googleusercontent.com',
    'lh3.googleusercontent.com',
    'covers.openlibrary.org',
    'images-na.ssl-images-amazon.com',
    'm.media-amazon.com',
    'i.gr-assets.com',
  ];

  private static readFromCache(key: string): CachedImage | null {
    const hit = ProxyController.cache.get(key);
    if (!hit) return null;
    if (Date.now() > hit.expiresAt) {
      ProxyController.cache.delete(key);
      return null;
    }
    // Refrescar posición (LRU sencillo)
    ProxyController.cache.delete(key);
    ProxyController.cache.set(key, hit);
    return hit;
  }

  private static writeToCache(key: string, value: CachedImage) {
    if (ProxyController.cache.size >= ProxyController.MAX_ENTRIES) {
      const oldest = ProxyController.cache.keys().next().value;
      if (oldest) ProxyController.cache.delete(oldest);
    }
    ProxyController.cache.set(key, value);
  }

  private sendImage(res: Response, img: CachedImage) {
    res.set({
      'Content-Type': img.contentType,
      'Cache-Control': 'public, max-age=604800, immutable', // 7 días en el navegador
      'ETag': img.etag,
      'Access-Control-Allow-Origin': '*',
      'Cross-Origin-Resource-Policy': 'cross-origin',
    });
    return res.send(img.buffer);
  }

  @Get('image')
  async proxyImage(@Query('url') url: string, @Res() res: Response) {
    if (!url) {
      return res.status(400).send('Missing url parameter');
    }

    try {
      const parsed = new URL(url);
      if (!ProxyController.ALLOWED_HOSTS.some(h => parsed.hostname === h || parsed.hostname.endsWith(`.${h}`))) {
        return res.status(403).send('Domain not allowed');
      }

      // 1) Servir desde caché si la tenemos
      const cached = ProxyController.readFromCache(url);
      if (cached) {
        return this.sendImage(res, cached);
      }

      // 2) Descargar de origen con un par de reintentos para 429/503
      let response: globalThis.Response | null = null;
      for (let attempt = 0; attempt < 3; attempt++) {
        response = await fetch(url, {
          headers: {
            'User-Agent': 'BuenasLecturas/1.0',
            'Accept': 'image/*',
          },
          redirect: 'follow',
        });
        if (response.ok) break;
        if (response.status === 429 || response.status === 503) {
          await new Promise(r => setTimeout(r, 300 * (attempt + 1)));
          continue;
        }
        break;
      }

      if (!response || !response.ok) {
        return res.status(response?.status ?? 502).send('Upstream error');
      }

      const contentType = response.headers.get('content-type') || 'image/jpeg';
      const buffer = Buffer.from(await response.arrayBuffer());

      // Open Library (y a veces Google Books) responden 200 OK con un GIF/PNG
      // de 1x1 px (~43 bytes) cuando la portada no existe, en vez de un 404.
      // Al no ser un error HTTP, el cliente no dispara su errorBuilder y pinta
      // un hueco transparente. Lo convertimos en 404 para que la app muestre
      // su placeholder con el título del libro.
      if (buffer.length < ProxyController.MIN_IMAGE_BYTES) {
        this.logger.debug(`Portada vacía (${buffer.length} bytes) para ${url}`);
        return res.status(404).set({ 'Access-Control-Allow-Origin': '*' }).send('Cover not available');
      }

      const etag = `"${createHash('md5').update(buffer).digest('hex')}"`;

      const entry: CachedImage = {
        buffer,
        contentType,
        etag,
        expiresAt: Date.now() + ProxyController.TTL_MS,
      };
      ProxyController.writeToCache(url, entry);

      return this.sendImage(res, entry);
    } catch (error) {
      this.logger.error(`Proxy error: ${error.message}`);
      return res.status(500).send('Proxy error');
    }
  }
}
