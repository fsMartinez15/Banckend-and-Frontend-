import { Component, ElementRef, inject, input, output, signal, viewChild, afterNextRender } from '@angular/core';
import { CheckoutLink, formatCop, Trip } from '../core/models';
import { RideGateway } from '../core/ride.gateway';
import { SessionService } from '../core/session.service';
import { errorMessage } from '../core/api-error';
@Component({ selector: 'app-payment', template: `
  <dialog #dialog (cancel)="close.emit()" (click)="backdrop($event)"><div class="payment-content">
    <button class="icon-button close" type="button" aria-label="Cerrar pago" (click)="close.emit()">×</button>
    <span class="payment-icon">↗</span>
    @if (demo) {
      <span class="eyebrow blue">PAGO · DEMOSTRACIÓN</span><h2>{{confirmed() ? 'Recorrido de prueba completado' : 'Tu viaje, a un paso.'}}</h2>
      <p class="muted">{{trip().origin}} → {{trip().destination}}</p>
      @if (confirmed()) { <div class="success-panel" role="status">Probaste el flujo de pago. No se realizó ningún cobro.</div><button class="button primary full" (click)="close.emit()">Entendido</button> }
      @else { <div class="payment-notice"><strong>Estás en la demostración.</strong><p>Inicia sesión con una cuenta real para pagar con Wompi.</p></div><button class="button primary full" (click)="confirmed.set(true)">Probar confirmación <span>→</span></button> }
    } @else {
      <span class="eyebrow blue">PAGO SEGURO · WOMPI</span><h2>Tu viaje, a un paso.</h2>
      <p class="muted">{{trip().origin}} → {{trip().destination}}</p>
      @if (error()) { <p class="form-error" role="alert">{{error()}}</p><button class="button subtle full retry" (click)="prepare()">Reintentar</button> }
      @else if (link(); as l) {
        <div class="payment-notice"><span class="fine">TOTAL A PAGAR</span><strong class="payment-amount">{{cop(l.amount_in_cents)}}</strong><p>Referencia {{l.reference}}. Pagarás en la página segura de Wompi con tarjeta, PSE, Nequi o Bancolombia y volverás a RideMove al terminar.</p></div>
        <a class="button primary full" [href]="l.url">Pagar con Wompi <span>↗</span></a>
      } @else { <div class="payment-notice" role="status">Preparando tu pago…</div> }
    }
  </div></dialog>` })
export class PaymentComponent {
  readonly trip = input.required<Trip>(); readonly close = output<void>();
  readonly confirmed = signal(false); readonly link = signal<CheckoutLink | null>(null); readonly error = signal('');
  readonly demo = inject(SessionService).isDemo(); private readonly rides = inject(RideGateway);
  readonly cop = formatCop;
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');
  constructor() { afterNextRender(() => { this.dialog().nativeElement.showModal(); if (!this.demo) this.prepare(); }); }
  prepare(): void {
    this.error.set(''); this.link.set(null);
    this.rides.checkout(this.trip().id).subscribe({ next: l => this.link.set(l), error: (e: unknown) => this.error.set(errorMessage(e)) });
  }
  backdrop(event: MouseEvent): void { if (event.target === this.dialog().nativeElement) this.close.emit(); }
}
