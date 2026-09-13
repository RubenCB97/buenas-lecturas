/**
 * Lector de CSV según RFC 4180: campos entre comillas con comas, comillas
 * escapadas ("") y saltos de línea dentro. Las reseñas del export de
 * Goodreads tienen todo eso, así que un `split(',')` no sirve.
 */
export function parseCsv(input: string): string[][] {
  // Quitamos el BOM que añaden Excel y algunos exportadores
  const text = input.charCodeAt(0) === 0xfeff ? input.slice(1) : input;

  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];

    if (inQuotes) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += ch;
      }
      continue;
    }

    if (ch === '"') {
      inQuotes = true;
    } else if (ch === ',') {
      row.push(field);
      field = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else {
      field += ch;
    }
  }

  // Última fila sin salto de línea final
  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }

  // Ignoramos filas totalmente vacías
  return rows.filter(r => r.some(cell => cell.trim().length > 0));
}

/** Convierte las filas en objetos usando la primera fila como cabecera. */
export function csvToObjects(input: string): Record<string, string>[] {
  const [header, ...rows] = parseCsv(input);
  if (!header) return [];
  const keys = header.map(h => h.trim());
  return rows.map(r => {
    const obj: Record<string, string> = {};
    keys.forEach((k, i) => (obj[k] = (r[i] ?? '').trim()));
    return obj;
  });
}
