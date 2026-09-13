import { buildAuthRedirect } from './google-auth.guard';

describe('buildAuthRedirect', () => {
  const result = { token: 'abc.def', user: '{"id":1,"firstName":"Rubén"}' };

  it('vuelve a la app móvil cuando el login empezó en la app', () => {
    const url = buildAuthRedirect('app', 'https://web.es', result);
    expect(url.startsWith('buenaslecturas://auth?token=abc.def&user=')).toBe(true);
    expect(decodeURIComponent(url.split('user=')[1])).toBe(result.user);
  });

  it('vuelve a la web en el resto de casos', () => {
    expect(buildAuthRedirect('web', 'https://web.es', result)).toMatch(/^https:\/\/web\.es\/tabs\/callback\?token=/);
    expect(buildAuthRedirect(undefined, 'https://web.es', result)).toMatch(/^https:\/\/web\.es\//);
  });

  it('informa del error al origen correcto', () => {
    expect(buildAuthRedirect('app', 'https://web.es', null)).toBe('buenaslecturas://auth?error=auth_failed');
    expect(buildAuthRedirect('web', 'https://web.es', null)).toBe('https://web.es/login?error=auth_failed');
  });
});
