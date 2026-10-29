import { TestBed } from '@angular/core/testing';
import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { beforeEach, afterEach, describe, expect, it } from 'vitest';
import { APP_CONFIG } from './config';
import { AuthGateway, HttpAuthGateway } from './auth.gateway';
import { SessionService } from './session.service';
import { authInterceptor } from './auth.interceptor';
import { SessionRideGateway } from './session-ride.gateway';
const base = 'http://127.0.0.1:8080';
describe('HTTP authentication boundary', () => {
  let http: HttpTestingController; let session: SessionService;
  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(withInterceptors([authInterceptor])), provideHttpClientTesting(), provideRouter([]), { provide: APP_CONFIG, useValue: { apiBaseUrl: base, demoEnabled: true } }, { provide: AuthGateway, useClass: HttpAuthGateway }, SessionRideGateway] });
    http = TestBed.inject(HttpTestingController); session = TestBed.inject(SessionService);
  });
  afterEach(() => { http.verify(); sessionStorage.clear(); });
  function login(): Promise<void> {
    const promise = firstValueFrom(session.login({ identifier: 'test@example.org', password: 'test-password' }));
    const req = http.expectOne(`${base}/api/auth/login`);
    expect(req.request.headers.has('Authorization')).toBe(false);
    req.flush({ access_token: 'initial-token', refresh_token: 'refresh-token', expires_in: 3600, token_type: 'bearer', user: { id: 'user-1', email: 'test@example.org' } });
    return promise;
  }
  it('attaches the token only to the configured backend', async () => {
    await login(); const client = TestBed.inject(HttpClient);
    const first = firstValueFrom(client.get(`${base}/api/profile`));
    const request = http.expectOne(`${base}/api/profile`); expect(request.request.headers.get('Authorization')).toBe('Bearer initial-token'); request.flush({}); await first;
    const external = firstValueFrom(client.get('https://external.example/api/profile'));
    const other = http.expectOne('https://external.example/api/profile'); expect(other.request.headers.has('Authorization')).toBe(false); other.flush({}); await external;
  });
  it('refreshes a rejected token and retries the original request', async () => {
    await login(); const result = firstValueFrom(TestBed.inject(HttpClient).get<{ id: string }>(`${base}/api/profile`));
    http.expectOne(`${base}/api/profile`).flush({}, { status: 401, statusText: 'Unauthorized' });
    const refresh = http.expectOne(`${base}/api/auth/refresh`); expect(refresh.request.body).toEqual({ refreshToken: 'refresh-token' });
    expect(refresh.request.headers.has('Authorization')).toBe(false);
    refresh.flush({ access_token: 'fresh-token', refresh_token: 'next-refresh', expires_in: 3600, token_type: 'bearer', user: { id: 'user-1', email: 'test@example.org' } });
    const retry = http.expectOne(`${base}/api/profile`); expect(retry.request.headers.get('Authorization')).toBe('Bearer fresh-token'); retry.flush({ id: 'user-1' });
    expect(await result).toEqual({ id: 'user-1' });
  });
  it('keeps email confirmation separate from an authenticated session', async () => {
    const result = firstValueFrom(session.register({ name: 'Example User', email: 'test@example.org', password: 'test-password', role: 'passenger', documentType: 'CC', documentNumber: '1069700001', phone: '3001234567' }));
    http.expectOne(`${base}/api/auth/register`).flush({ access_token: null, refresh_token: null, user: null });
    expect(await result).toBe(false); expect(session.authenticated()).toBe(false);
  });
  it('uses the real backend after leaving the demo in the same browser session', async () => {
    const rides = TestBed.inject(SessionRideGateway); session.enterDemo();
    expect((await firstValueFrom(rides.dashboard())).profile.id).toBe('demo-passenger');
    await login(); const result = firstValueFrom(rides.dashboard());
    http.expectOne(`${base}/api/profile`).flush({ id: 'real-user', name: 'Real User', role: 'passenger', active: true, available: false, phone: null });
    http.expectOne(`${base}/api/trips`).flush([]);
    http.expectOne(`${base}/api/payments`).flush([]);
    expect((await result).profile.id).toBe('real-user'); expect(session.isDemo()).toBe(false);
  });
  it('clears local tokens even if the logout service is unavailable', async () => {
    await login(); const result = firstValueFrom(session.logout());
    const assertion = expect(result).rejects.toBeDefined();
    http.expectOne(`${base}/api/auth/logout`).flush({}, { status: 503, statusText: 'Unavailable' });
    await assertion; expect(session.token()).toBeNull(); expect(session.authenticated()).toBe(false);
  });
  it('sends the cédula as login identifier', async () => {
    const result = firstValueFrom(session.login({ identifier: '1069700001', password: 'secret-pass' }));
    const req = http.expectOne(`${base}/api/auth/login`); expect(req.request.body).toEqual({ identifier: '1069700001', password: 'secret-pass' });
    req.flush({ access_token: 'tok', refresh_token: 'ref', expires_in: 3600, token_type: 'bearer', user: { id: 'u', email: 'c@x.co' } });
    await result; expect(session.authenticated()).toBe(true);
    expect(JSON.parse(sessionStorage.getItem('ridemove.session') ?? '{}').access_token).toBe('tok');
    const out = firstValueFrom(session.logout(), { defaultValue: undefined }); http.expectOne(`${base}/api/auth/logout`).flush(null, { status: 204, statusText: 'No Content' }); await out;
    expect(sessionStorage.getItem('ridemove.session')).toBeNull();
  });
  it('requests a signed Wompi checkout from the backend', async () => {
    await login();
    const result = firstValueFrom(TestBed.inject(SessionRideGateway).checkout('trip-1'));
    const req = http.expectOne(`${base}/api/payments/checkout`); expect(req.request.body).toEqual({ tripId: 'trip-1' });
    expect(req.request.headers.get('Authorization')).toBe('Bearer initial-token');
    req.flush({ url: 'https://checkout.wompi.co/p/?x=1', reference: 'RM-1', amount_in_cents: 800000, currency: 'COP' });
    expect((await result).amount_in_cents).toBe(800000);
  });
  it('accepts the create-trip contract: HTTP 201 with no response body', async () => {
    await login();
    const result = firstValueFrom(TestBed.inject(SessionRideGateway).requestTrip({ origin: 'Origen de prueba', destination: 'Destino de prueba' }));
    const request = http.expectOne(`${base}/api/trips`);
    expect(request.request.method).toBe('POST');
    request.flush(null, { status: 201, statusText: 'Created' });
    await result;
  });
});
