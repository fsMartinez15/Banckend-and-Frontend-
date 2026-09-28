import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { forkJoin, Observable } from 'rxjs';
import { APP_CONFIG } from './config';
import { DashboardData, Profile, Trip, TripRequest } from './models';
export abstract class RideGateway {
  abstract dashboard(): Observable<DashboardData>;
  abstract requestTrip(request: TripRequest): Observable<void>;
}
@Injectable({ providedIn: 'root' })
export class HttpRideGateway extends RideGateway {
  private readonly http = inject(HttpClient);
  private readonly url = `${inject(APP_CONFIG).apiBaseUrl}/api`;
  override dashboard(): Observable<DashboardData> {
    return forkJoin({ profile: this.http.get<Profile>(`${this.url}/profile`), trips: this.http.get<Trip[]>(`${this.url}/trips`) });
  }
  override requestTrip(request: TripRequest) { return this.http.post<void>(`${this.url}/trips`, request); }
}
