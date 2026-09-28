import { Component, ElementRef, input, output, signal, viewChild, afterNextRender } from '@angular/core';
import { Trip } from '../core/models';
@Component({ selector: 'app-payment-demo', template: `
  <dialog #dialog (cancel)="close.emit()" (click)="backdrop($event)"><div class="payment-content">
    <button class="icon-button close" type="button" aria-label="Cerrar pago" (click)="close.emit()">×</button>
    <span class="payment-icon">↗</span><span class="eyebrow blue">PAGO · DEMOSTRACIÓN</span><h2>{{confirmed() ? 'Recorrido de prueba completado' : 'Tu viaje, a un paso.'}}</h2>
    <p class="muted">{{trip().origin}} → {{trip().destination}}</p>
    @if (confirmed()) { <div class="success-panel" role="status">Probaste el flujo de pago. No se realizó ningún cobro ni se registró un pago.</div><button class="button primary full" (click)="close.emit()">Entendido</button> }
    @else { <div class="payment-notice"><strong>Este botón es una demostración.</strong><p>La tarifa y la pasarela de pagos aún no están conectadas. No se solicitarán datos de tarjeta ni se cobrará dinero.</p></div><button class="button primary full" (click)="confirmed.set(true)">Probar confirmación <span>→</span></button> }
  </div></dialog>` })
export class PaymentDemoComponent {
  readonly trip = input.required<Trip>(); readonly close = output<void>(); readonly confirmed = signal(false);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');
  constructor() { afterNextRender(() => this.dialog().nativeElement.showModal()); }
  backdrop(event: MouseEvent): void { if (event.target === this.dialog().nativeElement) this.close.emit(); }
}
