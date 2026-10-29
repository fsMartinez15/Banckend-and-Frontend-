import { Component, inject, signal } from '@angular/core';
import { AbstractControl, FormBuilder, ReactiveFormsModule, ValidationErrors, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { finalize } from 'rxjs';
import { AuthShellComponent } from './auth-shell.component';
import { SessionService } from '../core/session.service';
import { APP_CONFIG } from '../core/config';
import { errorMessage } from '../core/api-error';
/** Acepta un correo válido o un número de documento (5 a 16 letras/dígitos, admite puntos). */
export function emailOrDocument(control: AbstractControl): ValidationErrors | null {
  const value = String(control.value ?? '').trim();
  if (value.includes('@')) return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) ? null : { identifier: true };
  return /^[A-Za-z0-9]{5,16}$/.test(value.replace(/[\s.-]/g, '')) ? null : { identifier: true };
}
@Component({ selector: 'app-login', imports: [AuthShellComponent, ReactiveFormsModule, RouterLink], template: `
  <app-auth-shell><div class="auth-card"><span class="eyebrow blue">BIENVENIDO DE NUEVO</span><h2>Qué bueno verte.</h2><p class="muted">Ingresa con tu correo o tu número de cédula.</p>
    <form [formGroup]="form" (ngSubmit)="submit()">
      <label for="identifier">Correo electrónico o cédula</label><input id="identifier" autocomplete="username" formControlName="identifier" placeholder="tucorreo@ejemplo.com o 1069700001" maxlength="254">
      <label for="password">Contraseña</label><input id="password" type="password" autocomplete="current-password" formControlName="password" placeholder="Tu contraseña" maxlength="128">
      @if (invalid()) { <p class="form-error" role="alert">Escribe un correo o una cédula válidos y tu contraseña.</p> }
      @if (error()) { <p class="form-error" role="alert">{{error()}}</p> }
      <button class="button primary full" [disabled]="busy()" type="submit">{{busy() ? 'Ingresando…' : 'Iniciar sesión'}} <span>↗</span></button>
    </form>
    <p class="auth-switch">¿Es tu primer viaje? <a routerLink="/registro">Regístrate aquí</a></p>
    @if (config.demoEnabled) { <div class="demo-divider"><span>O CONOCE RIDEMOVE</span></div><button class="button subtle full" type="button" (click)="demo()">Explorar demostración <span>→</span></button><p class="fine center">Datos de ejemplo, sin crear una cuenta.</p> }
  </div></app-auth-shell>` })
export class LoginComponent {
  private readonly session = inject(SessionService);
  private readonly router = inject(Router);
  readonly config = inject(APP_CONFIG);
  readonly busy = signal(false); readonly error = signal(''); readonly invalid = signal(false);
  readonly form = inject(FormBuilder).nonNullable.group({ identifier: ['', [Validators.required, Validators.maxLength(254), emailOrDocument]], password: ['', [Validators.required, Validators.maxLength(128)]] });
  constructor() { if (this.session.authenticated() && !this.session.isDemo()) void this.router.navigateByUrl('/dashboard'); }
  submit(): void {
    if (this.busy()) return;
    this.invalid.set(this.form.invalid); this.error.set('');
    if (this.form.invalid) return;
    this.busy.set(true);
    const { identifier, password } = this.form.getRawValue();
    this.session.login({ identifier: identifier.trim(), password }).pipe(finalize(() => this.busy.set(false))).subscribe({ next: () => { void this.router.navigateByUrl('/dashboard'); }, error: (e: unknown) => this.error.set(errorMessage(e)) });
  }
  demo(): void { this.session.enterDemo(); void this.router.navigateByUrl('/dashboard'); }
}
