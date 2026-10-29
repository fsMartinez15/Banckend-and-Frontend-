import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { catchError, forkJoin, Observable, of } from 'rxjs';
import { APP_CONFIG } from './config';
import { CheckoutLink, DashboardData, Payment, PaymentResult, Profile, Trip, TripRequest } from './models';
export abstract class RideGateway {
  abstract dashboard(): Observable<DashboardData>;
  abstract requestTrip(request: TripRequest): Observable<void>;
  abstract checkout(tripId: string): Observable<CheckoutLink>;
}
@Injectable({ providedIn: 'root' })
export class HttpRideGateway extends RideGateway {
  private readonly http = inject(HttpClient);
  private readonly url = `${inject(APP_CONFIG).apiBaseUrl}/api`;
  override dashboard(): Observable<DashboardData> {
    return forkJoin({
      profile: this.http.get<Profile>(`${this.url}/profile`), trips: this.http.get<Trip[]>(`${this.url}/trips`),
      // El historial sigue visible aunque el módulo de pagos aún no esté disponible.
      payments: this.http.get<Payment[]>(`${this.url}/payments`).pipe(catchError(() => of([] as Payment[])))
    });
  }
  override requestTrip(request: TripRequest) { return this.http.post<void>(`${this.url}/trips`, request); }
  override checkout(tripId: string) { return this.http.post<CheckoutLink>(`${this.url}/payments/checkout`, { tripId }); }
  confirm(transactionId: string) { return this.http.post<PaymentResult>(`${this.url}/payments/confirm`, { transactionId }); }
}
