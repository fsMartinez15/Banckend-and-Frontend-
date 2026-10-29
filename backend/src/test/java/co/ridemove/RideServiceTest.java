package co.ridemove;
import co.ridemove.application.*;
import co.ridemove.application.port.out.*;
import co.ridemove.domain.*;
import org.junit.jupiter.api.*;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class RideServiceTest {
    ProfilePort people; TripPort rides; VehiclePort cars; LocationPort gps; RideService app;
    final Profile passenger=new Profile("p","Laura","","passenger",true,false);
    final Profile driver=new Profile("d","Fabián","","driver",true,true);
    Trip trip(String status,String owner,Integer rating) { return new Trip("t",owner,"d","Centro","Terminal",status,"2026-09-22",null,rating,null); }
    @BeforeEach void setup() {
        people=mock(ProfilePort.class); rides=mock(TripPort.class); cars=mock(VehiclePort.class); gps=mock(LocationPort.class);
        app=new RideService(people,rides,cars,gps);
        when(people.currentProfile()).thenReturn(passenger); when(rides.trips()).thenReturn(List.of());
        when(cars.vehicles()).thenReturn(List.of(new Vehicle("d","ABC123","Marca","2022","Gris","LIC")));
    }
    @Test void createsNormalizedRoute() { app.createTrip(" Centro "," Terminal "); verify(rides).requestTrip(TripDraft.of("Centro","Terminal")); }
    @Test void rejectsSameDestination() { assertThrows(BusinessRule.class,()->app.createTrip("Centro"," CENTRO ")); verify(rides,never()).requestTrip(any()); }
    @Test void rejectsSecondActiveRequest() { when(rides.trips()).thenReturn(List.of(trip("accepted","p",null))); assertThrows(BusinessRule.class,()->app.createTrip("Centro","Terminal")); }
    @Test void driverCannotCreateTrip() { when(people.currentProfile()).thenReturn(driver); assertThrows(BusinessRule.class,()->app.createTrip("Centro","Terminal")); }
    @Test void suspendedUserCannotReadTrips() { when(people.currentProfile()).thenReturn(new Profile("p","Laura","","passenger",false,false)); assertThrows(BusinessRule.class,()->app.trips()); }
    @Test void assignedDriverStartsTrip() { when(people.currentProfile()).thenReturn(driver); when(rides.trips()).thenReturn(List.of(trip("accepted","p",null))); app.transitionTrip("t","in_progress"); verify(rides).transitionTrip("t","in_progress"); }
    @Test void cannotSkipInProgress() { when(people.currentProfile()).thenReturn(driver); when(rides.trips()).thenReturn(List.of(trip("accepted","p",null))); assertThrows(BusinessRule.class,()->app.transitionTrip("t","completed")); }
    @Test void passengerCannotCompleteTrip() { when(rides.trips()).thenReturn(List.of(trip("in_progress","p",null))); assertThrows(BusinessRule.class,()->app.transitionTrip("t","completed")); }
    @Test void ratingRequiresOwnership() { when(rides.trips()).thenReturn(List.of(trip("completed","other",null))); assertThrows(BusinessRule.class,()->app.rateTrip("t",5,"")); }
    @Test void cannotRateTwice() { when(rides.trips()).thenReturn(List.of(trip("completed","p",5))); assertThrows(BusinessRule.class,()->app.rateTrip("t",5,"")); }
    @Test void ratingRangeIsEnforced() { when(rides.trips()).thenReturn(List.of(trip("completed","p",null))); assertThrows(BusinessRule.class,()->app.rateTrip("t",6,"")); }
    @Test void validRatingPersists() { when(rides.trips()).thenReturn(List.of(trip("completed","p",null))); app.rateTrip("t",5,"Bien"); verify(rides).rateTrip("t",5,"Bien"); }
    @Test void gpsRejectsInvalidCoordinates() { when(people.currentProfile()).thenReturn(driver); assertThrows(BusinessRule.class,()->app.saveLocation(91,0)); verifyNoInteractions(gps); }
    @Test void onlyAdminCanSuspend() { assertThrows(BusinessRule.class,()->app.setActive("d",false)); verify(people,never()).setActive(any(),anyBoolean()); }
    @Test void vehicleOwnerCannotBeSpoofed() { when(people.currentProfile()).thenReturn(driver); app.saveVehicle(new Vehicle("other","abc123","Marca","2024","Gris","LIC")); verify(cars).saveVehicle(new Vehicle("d","ABC123","Marca","2024","Gris","LIC")); }
    @Test void trackingRequiresActiveTrip() { when(people.currentProfile()).thenReturn(new Profile("d","Fabián","","driver",true,false)); assertThrows(BusinessRule.class,()->app.saveLocation(4.34,-74.36)); verifyNoInteractions(gps); }
    @Test void activeDriverCanPublishLocation() { when(people.currentProfile()).thenReturn(driver); when(rides.trips()).thenReturn(List.of(trip("in_progress","p",null))); app.saveLocation(4.34,-74.36); verify(gps).saveLocation(new DriverLocation("d",4.34,-74.36,null)); }
    @Test void adminCanCorrectDriverVehicle() {
        when(people.currentProfile()).thenReturn(new Profile("a","Admin","","admin",true,false)); when(people.profiles()).thenReturn(List.of(driver));
        app.saveVehicle(new Vehicle("d","xyz123","Marca","2025","Blanco","LIC")); verify(cars).saveVehicle(new Vehicle("d","XYZ123","Marca","2025","Blanco","LIC"));
    }

    Trip located(String status,String driverId) { return new Trip("t","p",driverId,"Centro","Terminal",status,"2026-10-29",null,null,null,4.33,-74.37,4.34,-74.36,1500,300,800000L,"cash",null,null,null,null); }
    @Test void requestWithCoordinatesAndPayment() {
        app.requestTrip(new TripDraft(" Centro ","Terminal",4.33,-74.37,4.34,-74.36,1500,300,"WOMPI"));
        verify(rides).requestTrip(new TripDraft("Centro","Terminal",4.33,-74.37,4.34,-74.36,1500,300,"wompi"));
    }
    @Test void requestRejectsPartialCoordinatesAndUnknownPayment() {
        assertThrows(BusinessRule.class,()->app.requestTrip(new TripDraft("Centro","Terminal",4.33,null,4.34,-74.36,1500,300,"cash")));
        assertThrows(BusinessRule.class,()->app.requestTrip(new TripDraft("Centro","Terminal",null,null,null,null,null,null,"bitcoin")));
        verify(rides,never()).requestTrip(any());
    }
    @Test void driverArrivesThenStarts() {
        when(people.currentProfile()).thenReturn(driver);
        when(rides.trips()).thenReturn(List.of(located("accepted","d"))); app.transitionTrip("t","arrived"); verify(rides).transitionTrip("t","arrived");
        when(rides.trips()).thenReturn(List.of(located("arrived","d"))); app.transitionTrip("t","in_progress"); verify(rides).transitionTrip("t","in_progress");
    }
    @Test void otherDriverCannotMarkArrival() {
        when(people.currentProfile()).thenReturn(driver); when(rides.trips()).thenReturn(List.of(located("accepted","x")));
        assertThrows(BusinessRule.class,()->app.transitionTrip("t","arrived"));
    }
    @Test void passengerCancelsWhileDriverIsComing() {
        when(rides.trips()).thenReturn(List.of(located("arrived","d"))); app.transitionTrip("t","cancelled"); verify(rides).transitionTrip("t","cancelled");
    }
    @Test void passengerCannotCancelStartedTrip() {
        when(rides.trips()).thenReturn(List.of(located("in_progress","d"))); assertThrows(BusinessRule.class,()->app.transitionTrip("t","cancelled"));
    }
    @Test void driverReleasesAcceptedTrip() {
        when(people.currentProfile()).thenReturn(driver); when(rides.trips()).thenReturn(List.of(located("accepted","d")));
        app.transitionTrip("t","pending"); verify(rides).transitionTrip("t","pending");
    }
    @Test void connectedDriverSharesLocationWithoutTrip() { when(people.currentProfile()).thenReturn(driver); app.saveLocation(4.34,-74.36); verify(gps).saveLocation(new DriverLocation("d",4.34,-74.36,null)); }
    @Test void tariffEstimateRoundsAndKeepsMinimum() {
        var t=new Tariff(350000,110000,25000,600000);
        assertEquals(600000,t.estimate(500,60));
        assertEquals(1280000,t.estimate(5000,900)); // 3.500 + 5 km·1.100 + 15 min·250 = 12.750 → 12.800
    }
}
