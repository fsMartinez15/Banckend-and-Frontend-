import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { finalize } from 'rxjs';
import { BrandComponent } from '../shared/brand.component';
import { MapArtComponent } from '../shared/map-art.component';
import { SessionService } from '../core/session.service';
import { RideGateway } from '../core/ride.gateway';
import { DashboardData, ROLE_LABEL, Trip, TripRequest } from '../core/models';
import { errorMessage } from '../core/api-error';
import { PaymentDemoComponent } from './payment-demo.component';
import { TripListComponent } from './trip-list.component';
import { TripRequestComponent } from './trip-request.component';
type Filter = 'all' | 'active' | 'completed';
@Component({ selector: 'app-dashboard', imports: [RouterLink, BrandComponent, MapArtComponent, PaymentDemoComponent, TripListComponent, TripRequestComponent], template: `
  <div class="workspace"><aside class="sidebar"><app-brand/><div class="side-label">MI ESPACIO</div><nav aria-label="Navegación principal"><a routerLink="/dashboard" fragment="overview" class="nav-item selected"><span>▦</span> Mi dashboard <i></i></a><a routerLink="/dashboard" fragment="trips" class="nav-item"><span>↗</span> Mis viajes</a></nav><div class="side-bottom"><div class="mini-card"><span>EL CAMINO ES MEJOR JUNTOS</span><strong>Muévete a tu manera.</strong><p>Un destino. Muchas posibilidades.</p></div><button class="nav-item logout" (click)="logout()" [disabled]="leaving()"><span>⇥</span> {{leaving() ? 'Saliendo…' : 'Cerrar sesión'}}</button></div></aside>
  <main class="dashboard" id="overview"><header class="topbar"><span>Mi espacio <b>/</b> <strong>Dashboard</strong></span><div class="user-pill"><span class="online-dot"></span><span>{{data()?.profile?.name ?? 'Mi cuenta'}}</span><span class="avatar">{{initial()}}</span></div></header>
    @if (session.isDemo()) { <div class="demo-banner"><span>DEMO</span> Estás explorando con datos de ejemplo. Los cambios no se guardan en la base de datos.</div> }
    <section class="page-heading"><div><span class="eyebrow blue">TU DÍA, EN MOVIMIENTO</span><h1>Hola, {{firstName()}}<span class="hello-dot">.</span></h1><p class="muted">Cada destino empieza con un buen plan.</p></div><button class="button subtle" (click)="load()" [disabled]="loading()">{{loading() ? 'Cargando…' : '↻ Actualizar'}}</button></section>
    @if (error()) { <div class="error-banner" role="alert">{{error()}}</div> }
    @if (notice()) { <div class="success-panel" role="status">{{notice()}}</div> }
    @if (data(); as view) {
      <div class="dashboard-grid"><section class="journey-card"><div class="journey-copy"><span class="eyebrow">ENCUENTRA TU PRÓXIMO DESTINO</span><h2>¿A dónde<br>vamos hoy?</h2><p>La ciudad te espera.<br>Nosotros te conectamos.</p><span class="illustration-note">Ilustración de recorrido</span></div><app-map-art/><span class="map-tag">↗ &nbsp; Tu próximo viaje</span></section>
        <section class="request-card"><span class="eyebrow blue">EMPIEZA AQUÍ</span><h2>Un nuevo viaje</h2>
          @if (!view.profile.active) { <p class="muted">Tu cuenta está suspendida. Contacta al administrador.</p> }
          @else if (view.profile.role !== 'passenger') { <p class="muted">Tu perfil es {{roles[view.profile.role]}}. Consulta tus viajes aquí y gestiona la operación desde la app móvil.</p> }
          @else if (activeCount() > 0) { <div class="active-trip"><span class="online-dot"></span><h3>Ya tienes un viaje activo</h3><p>Consulta su estado en Mis viajes. Usa Actualizar para ver los cambios.</p><a routerLink="/dashboard" fragment="trips" class="text-button">Ver mi viaje →</a></div> }
          @else { <app-trip-request [busy]="requesting()" (request)="requestTrip($event)"/> }
        </section></div>
      <section class="stats" aria-label="Resumen de viajes"><article><span class="stat-symbol blue">↗</span><div><span>Total de viajes</span><strong>{{view.trips.length}}</strong></div><small>Tu actividad</small></article><article><span class="stat-symbol green">✓</span><div><span>Viajes finalizados</span><strong>{{completedCount()}}</strong></div><small>Destinos alcanzados</small></article><article><span class="stat-symbol orange">◷</span><div><span>Viajes activos</span><strong>{{activeCount()}}</strong></div><small>En movimiento</small></article></section>
      <section class="history-card" id="trips"><div class="section-heading"><div><h2>Mis viajes</h2><p class="muted">Tu actividad, en un solo lugar.</p></div><div class="filters" aria-label="Filtrar viajes"><button [class.active]="filter() === 'all'" [attr.aria-pressed]="filter() === 'all'" (click)="filter.set('all')">Todos</button><button [class.active]="filter() === 'active'" [attr.aria-pressed]="filter() === 'active'" (click)="filter.set('active')">Activos</button><button [class.active]="filter() === 'completed'" [attr.aria-pressed]="filter() === 'completed'" (click)="filter.set('completed')">Finalizados</button></div></div><app-trip-list [trips]="filteredTrips()" [currentUserId]="view.profile.id" (pay)="payment.set($event)"/></section>
    } @else if (loading()) { <div class="loading-panel" role="status">Preparando tu espacio…</div> }
    <footer class="dashboard-footer"><span>RideMove · Movilidad que conecta</span><span>{{data() ? roles[data()!.profile.role] : ''}}</span></footer>
  </main></div>@if (payment(); as trip) { <app-payment-demo [trip]="trip" (close)="payment.set(null)"/> }` })
export class DashboardComponent implements OnInit {
  readonly session = inject(SessionService); private readonly rides = inject(RideGateway); private readonly router = inject(Router);
  readonly data = signal<DashboardData | null>(null); readonly loading = signal(false); readonly error = signal(''); readonly notice = signal('');
  readonly requesting = signal(false); readonly leaving = signal(false); readonly payment = signal<Trip | null>(null); readonly filter = signal<Filter>('all'); readonly roles = ROLE_LABEL;
  readonly firstName = computed(() => this.data()?.profile.name.split(' ')[0] ?? 'viajero');
  readonly initial = computed(() => this.firstName().charAt(0).toUpperCase());
  readonly activeCount = computed(() => this.data()?.trips.filter(t => ['pending', 'accepted', 'in_progress'].includes(t.status)).length ?? 0);
  readonly completedCount = computed(() => this.data()?.trips.filter(t => t.status === 'completed').length ?? 0);
  readonly filteredTrips = computed(() => (this.data()?.trips ?? []).filter(t => this.filter() === 'all' || (this.filter() === 'completed' ? t.status === 'completed' : ['pending', 'accepted', 'in_progress'].includes(t.status))));
  ngOnInit(): void { this.load(); }
  load(): void {
    if (this.loading()) return; this.loading.set(true); this.error.set('');
    this.rides.dashboard().pipe(finalize(() => this.loading.set(false))).subscribe({ next: data => this.data.set(data), error: (e: unknown) => this.error.set(errorMessage(e)) });
  }
  requestTrip(request: TripRequest): void {
    if (this.requesting()) return; this.requesting.set(true); this.error.set(''); this.notice.set('');
    this.rides.requestTrip(request).pipe(finalize(() => this.requesting.set(false))).subscribe({ next: () => { this.notice.set(this.session.isDemo() ? 'Solicitud simulada. Este viaje solo existe en esta demostración.' : 'Solicitud enviada. Estamos buscando un conductor.'); this.load(); }, error: (e: unknown) => this.error.set(errorMessage(e)) });
  }
  logout(): void {
    this.leaving.set(true); this.session.logout().subscribe({ next: () => { void this.router.navigateByUrl('/login'); }, error: () => { void this.router.navigateByUrl('/login'); } });
  }
}
