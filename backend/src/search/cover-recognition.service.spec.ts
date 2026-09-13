import { CoverRecognitionService } from './cover-recognition.service';

describe('CoverRecognitionService', () => {
  it('construye la búsqueda con título y primer autor', () => {
    expect(
      CoverRecognitionService.buildQuery({ isBook: true, title: 'Dune', authors: ['Frank Herbert', 'X'], isbn: null }),
    ).toBe('intitle:"Dune" inauthor:"Frank Herbert"');
    expect(CoverRecognitionService.buildQuery({ isBook: true, title: 'El "nombre"', authors: [], isbn: null })).toBe(
      'intitle:"El nombre"',
    );
    expect(CoverRecognitionService.buildQuery({ isBook: true, title: null, authors: ['A'], isbn: null })).toBeNull();
  });

  it('detecta el tipo de imagen por sus bytes', () => {
    const pad = Buffer.alloc(8);
    expect(CoverRecognitionService.sniffMime(Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), pad]))).toBe('image/jpeg');
    expect(
      CoverRecognitionService.sniffMime(Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), pad])),
    ).toBe('image/png');
    expect(CoverRecognitionService.sniffMime(Buffer.from('RIFF0000WEBPVP8 '))).toBe('image/webp');
    expect(CoverRecognitionService.sniffMime(Buffer.from('hola mundo, no soy imagen'))).toBeNull();
  });

  it('sin clave de API el servicio queda desactivado', () => {
    const prev = process.env.ANTHROPIC_API_KEY;
    delete process.env.ANTHROPIC_API_KEY;
    expect(new CoverRecognitionService({} as any).isEnabled).toBe(false);
    if (prev !== undefined) process.env.ANTHROPIC_API_KEY = prev;
  });
});
