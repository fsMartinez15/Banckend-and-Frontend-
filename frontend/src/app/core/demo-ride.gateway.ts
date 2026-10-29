import { Injectable } from '@angular/core';
import { delay, of, throwError } from 'rxjs';
import { RideGateway } from './ride.gateway';
import { Profile, Trip, TripRequest } from './models';
@Injectable({ providedIn: 'root' })
export class DemoRideGateway extends RideGateway {
  private readonly profile: Profile = { id: 'demo-passenger', name: 'Alex Rivera', phone: null, role: 'passenger', active: true, available: false, document_type: 'CC', document_number: '1069700001' };
  private trips: Trip[] = [
    { id: 'demo-001', passenger_id: 'demo-passenger', driver_id: 'demo-driver', origin: 'Universidad de Cundinamarca', destination: 'Plaza Mayor, Fusagasugá', status: 'completed', created_at: '2026-09-25T14:00:00-05:00', completed_at: '2026-09-25T14:12:00-05:00', rating: 5, comment: null },
    { id: 'demo-002', passenger_id: 'demo-passenger', driver_id: 'demo-driver', origin: 'Centro comercial La Querencia', destination: 'Terminal de transportes', status: 'completed', created_at: '2026-09-24T09:30:00-05:00', completed_at: '2026-09-24T09:45:00-05:00', rating: 4, comment: null },
    { id: 'demo-003', passenger_id: 'demo-passenger', driver_id: null, origin: 'Parque Coburgo', destination: 'Centro de Fusagasugá', status: 'cancelled', created_at: '2026-09-23T08:00:00-05:00', completed_at: null, rating: null, comment: null }
  ];
  override dashboard() { return of({ profile: this.profile, trips: [...this.trips], payments: [] }).pipe(delay(200)); }
  override checkout() { return throwError(() => new Error('En la demostración no se realizan cobros.')); }
  override requestTrip(request: TripRequest) {
    const trip: Trip = { id: crypto.randomUUID(), passenger_id: this.profile.id, driver_id: null, ...request, status: 'pending', created_at: new Date().toISOString(), completed_at: null, rating: null, comment: null };
    this.trips = [trip, ...this.trips];
    return of(undefined).pipe(delay(200));
  }
}
