import { Component, inject, signal } from '@angular/core';
import { AbstractControl, FormBuilder, ReactiveFormsModule, ValidationErrors, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { finalize } from 'rxjs';
import { AuthShellComponent } from './auth-shell.component';
import { SessionService } from '../core/session.service';
import { DOCUMENT_LABEL, DocumentType, RegistrationRole } from '../core/models';
import { errorMessage } from '../core/api-error';
/** Clientes: documento obligatorio. CC/TI solo dígitos (5-10); CE/PP alfanumérico (5-16). */
export function documentRule(group: AbstractControl): ValidationErrors | null {
  const role = group.get('role')?.value as RegistrationRole; const type = group.get('documentType')?.value as DocumentType;
  const doc = String(group.get('documentNumber')?.value ?? '').replace(/[\s.-]/g, '');
  if (!doc) return role === 'passenger' ? { documentRequired: true } : null;
  const valid = type === 'CC' || type === 'TI' ? /^\d{5,10}$/.test(doc) : /^[A-Za-z0-9]{5,16}$/.test(doc);
  return valid ? null : { documentInvalid: true };
}
@Component({ selector: 'app-register', imports: [AuthShellComponent, ReactiveFormsModule, RouterLink], template: `
  <app-auth-shell><div class="auth-card"><span class="eyebrow blue">EL CAMINO EMPIEZA AQUÍ</span><h2>Vamos a conectar.</h2><p class="muted">Crea tu cuenta con tu cédula y haz parte de RideMove.</p>
    @if (registered()) { <div class="success-panel" role="status"><strong>Revisa tu correo</strong><p>Si el registro fue aceptado, recibirás un enlace para confirmar tu cuenta. Después podrás iniciar sesión con tu correo o tu cédula.</p><a class="button primary" routerLink="/login">Volver al inicio</a></div> }
    @else { <form [formGroup]="form" (ngSubmit)="submit()">
      <label for="role">¿Cómo quieres moverte?</label><select id="role" formControlName="role"><option value="passenger">Quiero viajar · Cliente</option><option value="driver">Quiero conducir · Conductor</option></select>
      <label for="name">Nombre completo</label><input id="name" formControlName="name" autocomplete="name" placeholder="¿Cómo te llamas?" maxlength="80">
      <label for="documentNumber">Documento de identidad{{form.controls.role.value === 'driver' ? ' (opcional)' : ''}}</label>
      <div class="field-row"><select id="documentType" aria-label="Tipo de documento" formControlName="documentType">@for (t of types; track t) { <option [value]="t">{{t}}</option> }</select><input id="documentNumber" formControlName="documentNumber" inputmode="numeric" autocomplete="off" placeholder="Número de cédula" maxlength="20"></div>
      <p class="fine field-hint">{{labels[form.controls.documentType.value]}}. Con este número también podrás iniciar sesión.</p>
      <label for="phone">Celular</label><input id="phone" formControlName="phone" type="tel" inputmode="tel" autocomplete="tel" placeholder="3001234567" maxlength="15">
      <label for="email">Correo electrónico</label><input id="email" formControlName="email" type="email" autocomplete="email" placeholder="tucorreo@ejemplo.com" maxlength="254">
      <label for="password">Contraseña</label><input id="password" formControlName="password" type="password" autocomplete="new-password" placeholder="Mínimo 8 caracteres" minlength="8" maxlength="128">
      @if (invalid()) { <p class="form-error" role="alert">{{invalidMessage()}}</p> }
      @if (error()) { <p class="form-error" role="alert">{{error()}}</p> }
      <button class="button primary full" type="submit" [disabled]="busy()">{{busy() ? 'Creando cuenta…' : 'Crear mi cuenta'}} <span>↗</span></button>
    </form> }
    <p class="auth-switch">¿Ya tienes cuenta? <a routerLink="/login">Inicia sesión</a></p>
  </div></app-auth-shell>` })
export class RegisterComponent {
  private readonly session = inject(SessionService); private readonly router = inject(Router);
  readonly busy = signal(false); readonly error = signal(''); readonly invalid = signal(false); readonly registered = signal(false); readonly invalidMessage = signal('');
  readonly types: DocumentType[] = ['CC', 'CE', 'PP', 'TI']; readonly labels = DOCUMENT_LABEL;
  readonly form = inject(FormBuilder).nonNullable.group({
    role: ['passenger' as RegistrationRole, Validators.required],
    name: ['', [Validators.required, Validators.minLength(2), Validators.maxLength(80)]],
    documentType: ['CC' as DocumentType, Validators.required], documentNumber: [''],
    phone: ['', [Validators.pattern(/^\+?[0-9 ]{7,15}$/)]],
    email: ['', [Validators.required, Validators.email, Validators.maxLength(254)]],
    password: ['', [Validators.required, Validators.minLength(8), Validators.maxLength(128)]]
  }, { validators: documentRule });
  submit(): void {
    if (this.busy()) return;
    this.error.set(''); this.invalid.set(this.form.invalid);
    if (this.form.invalid) {
      const e = this.form.errors;
      this.invalidMessage.set(e?.['documentRequired'] ? 'Para registrarte como cliente escribe tu número de cédula.' : e?.['documentInvalid'] ? 'Revisa el número de documento: la cédula lleva de 5 a 10 dígitos.' : 'Revisa tu nombre, celular, correo y una contraseña de al menos 8 caracteres.');
      return;
    }
    this.busy.set(true);
    const v = this.form.getRawValue();
    const data = { ...v, name: v.name.trim(), email: v.email.trim(), documentNumber: v.documentNumber.replace(/[\s.-]/g, ''), phone: v.phone.replace(/\s/g, '') };
    this.session.register(data).pipe(finalize(() => this.busy.set(false))).subscribe({ next: authenticated => { if (authenticated) void this.router.navigateByUrl('/dashboard'); else this.registered.set(true); }, error: (e: unknown) => this.error.set(errorMessage(e)) });
  }
}
