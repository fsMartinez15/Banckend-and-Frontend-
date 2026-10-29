import { inject, Injectable } from '@angular/core';
import { DemoRideGateway } from './demo-ride.gateway';
import { RideGateway, HttpRideGateway } from './ride.gateway';
import { SessionService } from './session.service';
import { TripRequest } from './models';
@Injectable()
export class SessionRideGateway extends RideGateway {
  private readonly session = inject(SessionService);
  private readonly demo = inject(DemoRideGateway);
  private readonly http = inject(HttpRideGateway);
  private get adapter(): RideGateway { return this.session.isDemo() ? this.demo : this.http; }
  override dashboard() { return this.adapter.dashboard(); }
  override requestTrip(request: TripRequest) { return this.adapter.requestTrip(request); }
  override checkout(tripId: string) { return this.adapter.checkout(tripId); }
}
