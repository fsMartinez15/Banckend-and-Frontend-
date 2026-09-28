import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { finalize } from 'rxjs';
import { AuthShellComponent } from './auth-shell.component';
import { SessionService } from '../core/session.service';
import { APP_CONFIG } from '../core/config';
import { errorMessage } from '../core/api-error';
@Component({ selector: 'app-login', imports: [AuthShellComponent, ReactiveFormsModule, RouterLink], template: `
  <app-auth-shell><div class="auth-card"><span class="eyebrow blue">BIENVENIDO DE NUEVO</span><h2>Qué bueno verte.</h2><p class="muted">Ingresa a tu cuenta y elige tu próximo destino.</p>
    <form [formGroup]="form" (ngSubmit)="submit()">
      <label for="email">Correo electrónico</label><input id="email" type="email" autocomplete="email" formControlName="email" placeholder="tucorreo@ejemplo.com" maxlength="254">
      <label for="password">Contraseña</label><input id="password" type="password" autocomplete="current-password" formControlName="password" placeholder="Tu contraseña" maxlength="128">
      @if (invalid()) { <p class="form-error" role="alert">Escribe un correo válido y tu contraseña.</p> }
      @if (error()) { <p class="form-error" role="alert">{{error()}}</p> }
      <button class="button primary full" [disabled]="busy()" type="submit">{{busy() ? 'Ingresando…' : 'Iniciar sesión'}} <span>↗</span></button>
    </form>
    <p class="auth-switch">¿Es tu primer viaje? <a routerLink="/registro">Crea tu cuenta</a></p>
    @if (config.demoEnabled) { <div class="demo-divider"><span>O CONOCE RIDEMOVE</span></div><button class="button subtle full" type="button" (click)="demo()">Explorar demostración <span>→</span></button><p class="fine center">Datos de ejemplo, sin crear una cuenta.</p> }
  </div></app-auth-shell>` })
export class LoginComponent {
  private readonly session = inject(SessionService);
  private readonly router = inject(Router);
  readonly config = inject(APP_CONFIG);
  readonly busy = signal(false); readonly error = signal(''); readonly invalid = signal(false);
  readonly form = inject(FormBuilder).nonNullable.group({ email: ['', [Validators.required, Validators.email, Validators.maxLength(254)]], password: ['', [Validators.required, Validators.maxLength(128)]] });
  submit(): void {
    if (this.busy()) return;
    this.invalid.set(this.form.invalid); this.error.set('');
    if (this.form.invalid) return;
    this.busy.set(true);
    this.session.login(this.form.getRawValue()).pipe(finalize(() => this.busy.set(false))).subscribe({ next: () => { void this.router.navigateByUrl('/dashboard'); }, error: (e: unknown) => this.error.set(errorMessage(e)) });
  }
  demo(): void { this.session.enterDemo(); void this.router.navigateByUrl('/dashboard'); }
}
