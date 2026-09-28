import { computed, inject, Injectable, signal } from '@angular/core';
import { finalize, map, Observable, of, shareReplay, tap, throwError } from 'rxjs';
import { APP_CONFIG } from './config';
import { AuthGateway } from './auth.gateway';
import { AuthSession, Credentials, Registration } from './models';
@Injectable({ providedIn: 'root' })
export class SessionService {
  private readonly gateway = inject(AuthGateway);
  private readonly config = inject(APP_CONFIG);
  private readonly session = signal<AuthSession | null>(null);
  private readonly demo = signal(false);
  private refreshing: Observable<string> | null = null;
  readonly isDemo = this.demo.asReadonly();
  readonly token = computed(() => this.session()?.access_token ?? null);
  readonly authenticated = computed(() => this.isDemo() || !!this.token());
  login(data: Credentials): Observable<void> {
    return this.gateway.login(data).pipe(map(session => {
      if (!session.access_token) throw new Error('No se recibió una sesión. Verifica tu correo.');
      this.demo.set(false); this.session.set(session);
    }));
  }
  register(data: Registration): Observable<boolean> {
    return this.gateway.register(data).pipe(map(session => {
      if (session.access_token) { this.demo.set(false); this.session.set(session); return true; }
      return false;
    }));
  }
  enterDemo(): void {
    if (!this.config.demoEnabled) return;
    this.session.set(null); this.demo.set(true);
  }
  clear(): void { this.session.set(null); this.demo.set(false); }
  logout(): Observable<void> {
    const request = this.isDemo() ? of(undefined) : this.gateway.logout();
    return request.pipe(finalize(() => this.clear()));
  }
  refresh(): Observable<string> {
    if (this.refreshing) return this.refreshing;
    const token = this.session()?.refresh_token;
    if (!token) return throwError(() => new Error('Vuelve a iniciar sesión.'));
    this.refreshing = this.gateway.refresh(token).pipe(
      tap(session => this.session.set(session)),
      map(session => { if (!session.access_token) throw new Error('Sesión vencida.'); return session.access_token; }),
      finalize(() => { this.refreshing = null; }), shareReplay({ bufferSize: 1, refCount: false })
    );
    return this.refreshing;
  }
}
