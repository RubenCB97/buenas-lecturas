import { csvToObjects, parseCsv } from './csv.util';

describe('parseCsv', () => {
  it('lee campos simples', () => {
    expect(parseCsv('a,b,c\n1,2,3')).toEqual([['a', 'b', 'c'], ['1', '2', '3']]);
  });

  it('respeta comas, comillas escapadas y saltos de línea entre comillas', () => {
    const csv = 'Title,My Review\n"Dune","Genial, de verdad.\nDiría ""obra maestra"""\n';
    expect(parseCsv(csv)).toEqual([
      ['Title', 'My Review'],
      ['Dune', 'Genial, de verdad.\nDiría "obra maestra"'],
    ]);
  });

  it('acepta CRLF, BOM y líneas vacías', () => {
    expect(parseCsv('﻿a,b\r\n\r\n1,2\r\n')).toEqual([['a', 'b'], ['1', '2']]);
  });

  it('conserva campos vacíos', () => {
    expect(parseCsv('a,b,c\n1,,3')).toEqual([['a', 'b', 'c'], ['1', '', '3']]);
  });
});

describe('csvToObjects', () => {
  it('usa la cabecera como claves', () => {
    expect(csvToObjects('Title,Author\nDune,Frank Herbert')).toEqual([{ Title: 'Dune', Author: 'Frank Herbert' }]);
  });
});
