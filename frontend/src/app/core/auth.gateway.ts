import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { APP_CONFIG } from './config';
import { AuthSession, Credentials, Registration } from './models';
export abstract class AuthGateway {
  abstract login(data: Credentials): Observable<AuthSession>;
  abstract register(data: Registration): Observable<AuthSession>;
  abstract refresh(refreshToken: string): Observable<AuthSession>;
  abstract logout(): Observable<void>;
}
@Injectable({ providedIn: 'root' })
export class HttpAuthGateway extends AuthGateway {
  private readonly http = inject(HttpClient);
  private readonly url = `${inject(APP_CONFIG).apiBaseUrl}/api/auth`;
  override login(data: Credentials) { return this.http.post<AuthSession>(`${this.url}/login`, data); }
  override register(data: Registration) { return this.http.post<AuthSession>(`${this.url}/register`, data); }
  override refresh(refreshToken: string) { return this.http.post<AuthSession>(`${this.url}/refresh`, { refreshToken }); }
  override logout() { return this.http.post<void>(`${this.url}/logout`, {}); }
}
