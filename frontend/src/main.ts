import { bootstrapApplication } from '@angular/platform-browser';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideRouter, withInMemoryScrolling } from '@angular/router';
import { registerLocaleData } from '@angular/common';
import localeEs from '@angular/common/locales/es';
import { LOCALE_ID } from '@angular/core';
import { AppComponent } from './app/app.component';
import { routes } from './app/app.routes';
import { APP_CONFIG, parseConfig } from './app/core/config';
import { AuthGateway, HttpAuthGateway } from './app/core/auth.gateway';
import { authInterceptor } from './app/core/auth.interceptor';
async function start(): Promise<void> {
  const response = await fetch('/config.json', { cache: 'no-store' });
  if (!response.ok) throw new Error('Falta la configuración del entorno.');
  const raw: unknown = await response.json();
  const config = parseConfig(raw); registerLocaleData(localeEs);
  await bootstrapApplication(AppComponent, { providers: [provideRouter(routes, withInMemoryScrolling({ anchorScrolling: 'enabled' })), provideHttpClient(withInterceptors([authInterceptor])), { provide: APP_CONFIG, useValue: config }, { provide: LOCALE_ID, useValue: 'es' }, { provide: AuthGateway, useClass: HttpAuthGateway }] });
}
void start().catch(() => { const root = document.querySelector('app-root'); if (root) root.textContent = 'No pudimos iniciar RideMove. Revisa la configuración del entorno y recarga la página.'; });
