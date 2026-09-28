import { Component, inject, input, output, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { TripRequest } from '../core/models';
@Component({ selector: 'app-trip-request', imports: [ReactiveFormsModule], template: `
  <form class="request-form" [formGroup]="form" (ngSubmit)="submit()"><label for="origin">Punto de partida</label><div class="location-input"><span class="pin blue-pin"></span><input id="origin" formControlName="origin" placeholder="¿Dónde te recogemos?" maxlength="160"></div><label for="destination">Tu destino</label><div class="location-input"><span class="pin orange-pin"></span><input id="destination" formControlName="destination" placeholder="¿A dónde vamos?" maxlength="160"></div>@if (invalid()) { <p class="form-error" role="alert">Ingresa un origen y destino diferentes, de al menos 3 caracteres.</p> }<button class="button dark full" type="submit" [disabled]="busy()">{{busy() ? 'Solicitando…' : 'Solicitar viaje'}} <span>↗</span></button></form>` })
export class TripRequestComponent {
  readonly busy = input(false); readonly request = output<TripRequest>(); readonly invalid = signal(false);
  readonly form = inject(FormBuilder).nonNullable.group({ origin: ['', [Validators.required, Validators.minLength(3), Validators.maxLength(160)]], destination: ['', [Validators.required, Validators.minLength(3), Validators.maxLength(160)]] });
  submit(): void {
    if (this.busy()) return;
    const value = this.form.getRawValue(); const origin = value.origin.trim(); const destination = value.destination.trim();
    this.invalid.set(this.form.invalid || origin.length < 3 || destination.length < 3 || origin.toLowerCase() === destination.toLowerCase());
    if (!this.invalid()) this.request.emit({ origin, destination });
  }
}
