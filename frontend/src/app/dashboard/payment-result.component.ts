import { Component, inject, OnInit, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { AuthShellComponent } from '../auth/auth-shell.component';
import { HttpRideGateway } from '../core/ride.gateway';
import { SessionService } from '../core/session.service';
import { formatCop, PaymentResult } from '../core/models';
import { errorMessage } from '../core/api-error';
const TITLES: Record<string, string> = { APPROVED: '¡Pago aprobado!', PENDING: 'Tu pago está en proceso', DECLINED: 'El pago fue rechazado', VOIDED: 'El pago fue anulado', ERROR: 'No se pudo completar el pago' };
/** Página de retorno del Web Checkout de Wompi (?id=<transacción>). */
@Component({ selector: 'app-payment-result', imports: [AuthShellComponent, RouterLink], template: `
  <app-auth-shell><div class="auth-card"><span class="eyebrow blue">RESULTADO DEL PAGO · WOMPI</span>
    @if (result(); as r) {
      <h2>{{titles[r.status] ?? r.status}}</h2>
      <div [class]="r.status === 'APPROVED' ? 'success-panel' : 'payment-notice'" role="status"><strong>{{cop(r.amount_in_cents)}}</strong><p>Referencia {{r.reference}}@if (r.payment_method) { · {{r.payment_method}} }</p>
        @if (r.status === 'PENDING') { <p>Algunos medios (PSE, Nequi) tardan unos minutos. Puedes consultar de nuevo.</p> }
        @if (r.status === 'DECLINED' || r.status === 'ERROR') { <p>No se realizó el cobro. Puedes intentarlo otra vez desde Mis viajes.</p> }
      </div>
      @if (r.status === 'PENDING') { <button class="button subtle full" (click)="check()" [disabled]="busy()">{{busy() ? 'Consultando…' : 'Consultar de nuevo'}}</button> }
    } @else if (error()) { <h2>No pudimos verificar el pago</h2><p class="form-error" role="alert">{{error()}}</p><button class="button subtle full" (click)="check()" [disabled]="busy()">Reintentar</button> }
    @else { <h2>Verificando tu pago…</h2><p class="muted">Estamos consultando el estado con Wompi.</p> }
    <a class="button primary full back" [routerLink]="session.authenticated() ? '/dashboard' : '/login'">{{session.authenticated() ? 'Volver a mis viajes' : 'Iniciar sesión'}} <span>→</span></a>
  </div></app-auth-shell>` })
export class PaymentResultComponent implements OnInit {
  readonly session = inject(SessionService); private readonly gateway = inject(HttpRideGateway); private readonly route = inject(ActivatedRoute);
  readonly result = signal<PaymentResult | null>(null); readonly error = signal(''); readonly busy = signal(false);
  readonly titles = TITLES; readonly cop = formatCop;
  ngOnInit(): void { this.check(); }
  check(): void {
    const id = this.route.snapshot.queryParamMap.get('id');
    if (!id) { this.error.set('El enlace no incluye una transacción de Wompi.'); return; }
    this.busy.set(true); this.error.set('');
    this.gateway.confirm(id).subscribe({ next: r => { this.result.set(r); this.busy.set(false); }, error: (e: unknown) => { this.error.set(errorMessage(e)); this.busy.set(false); } });
  }
}
