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

  it('se activa con clave de Gemini o de Claude', () => {
    const prev = { g: process.env.GEMINI_API_KEY, a: process.env.ANTHROPIC_API_KEY };
    delete process.env.GEMINI_API_KEY;
    delete process.env.ANTHROPIC_API_KEY;
    const service = new CoverRecognitionService({} as any);
    expect(service.isEnabled).toBe(false);
    process.env.GEMINI_API_KEY = 'x';
    expect(service.isEnabled).toBe(true);
    delete process.env.GEMINI_API_KEY;
    if (prev.g !== undefined) process.env.GEMINI_API_KEY = prev.g;
    if (prev.a !== undefined) process.env.ANTHROPIC_API_KEY = prev.a;
  });

  it('extrae el texto de una respuesta de Gemini', () => {
    const body = {
      status: 'completed',
      steps: [
        { type: 'thought', content: [{ type: 'text', text: 'ignorar' }] },
        { type: 'model_output', content: [{ type: 'text', text: '{"isBook":true,' }, { type: 'text', text: '"title":"Dune"}' }] },
      ],
    };
    expect(CoverRecognitionService.extractGeminiText(body)).toBe('{"isBook":true,"title":"Dune"}');
    expect(CoverRecognitionService.extractGeminiText({ steps: [] })).toBeNull();
  });

  it('interpreta la lectura aunque venga entre bloques de código', () => {
    expect(
      CoverRecognitionService.parseReading('```json\n{"isBook":true,"title":" Dune ","authors":["Frank Herbert",""],"isbn":null}\n```'),
    ).toEqual({ isBook: true, title: 'Dune', authors: ['Frank Herbert'], isbn: null });
    expect(CoverRecognitionService.parseReading('no es json').isBook).toBe(false);
  });
});
