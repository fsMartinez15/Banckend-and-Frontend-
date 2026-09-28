import { inject } from '@angular/core';
import { CanActivateFn, Router, Routes } from '@angular/router';
import { SessionService } from './core/session.service';
import { RideGateway } from './core/ride.gateway';
import { SessionRideGateway } from './core/session-ride.gateway';
const authenticated: CanActivateFn = () => inject(SessionService).authenticated() || inject(Router).createUrlTree(['/login']);
// El adaptador se elige en cada operación, incluso al cambiar de sesión sin recargar.
export const routes: Routes = [
  { path: 'login', loadComponent: () => import('./auth/login.component').then(m => m.LoginComponent) },
  { path: 'registro', loadComponent: () => import('./auth/register.component').then(m => m.RegisterComponent) },
  { path: 'dashboard', canActivate: [authenticated], providers: [{ provide: RideGateway, useClass: SessionRideGateway }], loadComponent: () => import('./dashboard/dashboard.component').then(m => m.DashboardComponent) },
  { path: '', pathMatch: 'full', redirectTo: 'login' }, { path: '**', redirectTo: 'login' }
];
