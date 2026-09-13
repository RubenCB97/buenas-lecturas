import { PushService } from './push.service';

describe('PushService.parseServiceAccount', () => {
  const account = { type: 'service_account', client_email: 'x@y.iam.gserviceaccount.com', private_key: 'KEY' };

  it('acepta el JSON tal cual', () => {
    expect(PushService.parseServiceAccount(JSON.stringify(account))).toEqual(account);
  });

  it('acepta el JSON en base64', () => {
    const b64 = Buffer.from(JSON.stringify(account)).toString('base64');
    expect(PushService.parseServiceAccount(b64)).toEqual(account);
  });

  it('rechaza valores vacíos o que no son una cuenta de servicio', () => {
    expect(PushService.parseServiceAccount(undefined)).toBeNull();
    expect(PushService.parseServiceAccount('  ')).toBeNull();
    expect(PushService.parseServiceAccount('{"foo":1}')).toBeNull();
    expect(PushService.parseServiceAccount('no-es-json')).toBeNull();
  });
});
