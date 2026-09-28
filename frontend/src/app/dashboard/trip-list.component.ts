import { Component, input, output } from '@angular/core';
import { DatePipe } from '@angular/common';
import { STATUS_LABEL, Trip } from '../core/models';
@Component({ selector: 'app-trip-list', imports: [DatePipe], template: `
  <div class="trip-list">@for (trip of trips(); track trip.id) {
    <article class="trip-row"><span class="trip-icon">↗</span><div class="trip-route"><strong>{{trip.destination}}</strong><span>Desde {{trip.origin}}</span><small>{{trip.created_at | date:'dd MMM yyyy · HH:mm'}} · {{trip.id.slice(0, 8)}}</small></div><span class="status" [class]="'status ' + trip.status">{{labels[trip.status]}}</span><div class="trip-action">@if(trip.status === 'completed' && trip.passenger_id === currentUserId()) { <button class="text-button" (click)="pay.emit(trip)">Pagar · demo ↗</button> } @else { <span class="muted">—</span> }</div></article>
  } @empty { <div class="empty-state"><span>↗</span><h3>Tu próxima historia está por comenzar</h3><p>Los viajes de esta categoría aparecerán aquí.</p></div> }</div>` })
export class TripListComponent { readonly trips = input.required<Trip[]>(); readonly currentUserId = input.required<string>(); readonly pay = output<Trip>(); readonly labels = STATUS_LABEL; }
