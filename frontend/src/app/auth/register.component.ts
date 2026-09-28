import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { finalize } from 'rxjs';
import { AuthShellComponent } from './auth-shell.component';
import { SessionService } from '../core/session.service';
import { RegistrationRole } from '../core/models';
import { errorMessage } from '../core/api-error';
@Component({ selector: 'app-register', imports: [AuthShellComponent, ReactiveFormsModule, RouterLink], template: `
  <app-auth-shell><div class="auth-card"><span class="eyebrow blue">EL CAMINO EMPIEZA AQUÍ</span><h2>Vamos a conectar.</h2><p class="muted">Crea tu cuenta y haz parte de RideMove.</p>
    @if (registered()) { <div class="success-panel" role="status"><strong>Revisa tu correo</strong><p>Si el registro fue aceptado, recibirás un enlace para confirmar tu cuenta. Después podrás iniciar sesión.</p><a class="button primary" routerLink="/login">Volver al inicio</a></div> }
    @else { <form [formGroup]="form" (ngSubmit)="submit()">
      <label for="name">Nombre completo</label><input id="name" formControlName="name" autocomplete="name" placeholder="¿Cómo te llamas?" maxlength="80">
      <label for="email">Correo electrónico</label><input id="email" formControlName="email" type="email" autocomplete="email" placeholder="tucorreo@ejemplo.com" maxlength="254">
      <label for="password">Contraseña</label><input id="password" formControlName="password" type="password" autocomplete="new-password" placeholder="Mínimo 8 caracteres" minlength="8" maxlength="128">
      <label for="role">¿Cómo quieres moverte?</label><select id="role" formControlName="role"><option value="passenger">Quiero viajar · Pasajero</option><option value="driver">Quiero conducir · Conductor</option></select>
      @if (invalid()) { <p class="form-error" role="alert">Revisa tu nombre, correo y contraseña de al menos 8 caracteres.</p> }
      @if (error()) { <p class="form-error" role="alert">{{error()}}</p> }
      <button class="button primary full" type="submit" [disabled]="busy()">{{busy() ? 'Creando cuenta…' : 'Crear mi cuenta'}} <span>↗</span></button>
    </form> }
    <p class="auth-switch">¿Ya tienes cuenta? <a routerLink="/login">Inicia sesión</a></p>
  </div></app-auth-shell>` })
export class RegisterComponent {
  private readonly session = inject(SessionService); private readonly router = inject(Router);
  readonly busy = signal(false); readonly error = signal(''); readonly invalid = signal(false); readonly registered = signal(false);
  readonly form = inject(FormBuilder).nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2), Validators.maxLength(80)]],
    email: ['', [Validators.required, Validators.email, Validators.maxLength(254)]],
    password: ['', [Validators.required, Validators.minLength(8), Validators.maxLength(128)]], role: ['passenger' as RegistrationRole, Validators.required]
  });
  submit(): void {
    if (this.busy()) return;
    this.invalid.set(this.form.invalid); this.error.set(''); if (this.form.invalid) return;
    this.busy.set(true);
    this.session.register(this.form.getRawValue()).pipe(finalize(() => this.busy.set(false))).subscribe({ next: authenticated => { if (authenticated) void this.router.navigateByUrl('/dashboard'); else this.registered.set(true); }, error: (e: unknown) => this.error.set(errorMessage(e)) });
  }
}
