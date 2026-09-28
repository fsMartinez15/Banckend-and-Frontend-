import { inject } from '@angular/core';
import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { Router } from '@angular/router';
import { catchError, switchMap, throwError } from 'rxjs';
import { APP_CONFIG } from './config';
import { SessionService } from './session.service';
export const authInterceptor: HttpInterceptorFn = (request, next) => {
  const config = inject(APP_CONFIG);
  const session = inject(SessionService);
  const router = inject(Router);
  const api = `${config.apiBaseUrl}/api/`;
  const publicAuth = ['login', 'register', 'refresh'].some(path => request.url === `${api}auth/${path}`);
  const token = session.token();
  if (!request.url.startsWith(api) || publicAuth || !token) return next(request);
  return next(request.clone({ setHeaders: { Authorization: `Bearer ${token}` } })).pipe(
    catchError((error: unknown) => {
      if (!(error instanceof HttpErrorResponse) || error.status !== 401 || request.url.endsWith('/logout')) return throwError(() => error);
      return session.refresh().pipe(
        catchError((refreshError: unknown) => { session.clear(); void router.navigateByUrl('/login'); return throwError(() => refreshError); }),
        switchMap(fresh => next(request.clone({ setHeaders: { Authorization: `Bearer ${fresh}` } })))
      );
    })
  );
};
