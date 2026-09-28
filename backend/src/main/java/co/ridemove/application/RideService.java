package co.ridemove.application;
import co.ridemove.application.port.in.RideUseCases;
import co.ridemove.application.port.out.*;
import co.ridemove.domain.*;
import java.util.List;
import static co.ridemove.domain.BusinessRule.*;

/** Pure Java application service. No Spring, HTTP, SQL or Supabase imports. */
public final class RideService implements RideUseCases {
    private final ProfilePort people;
    private final TripPort rides;
    private final VehiclePort cars;
    private final LocationPort gps;
    public RideService(ProfilePort people, TripPort rides, VehiclePort cars, LocationPort gps) {
        this.people=people; this.rides=rides; this.cars=cars; this.gps=gps;
    }
    public Profile profile() { return people.currentProfile(); }
    private Profile actor() { var p=profile(); p.requireActive(); return p; }
    public List<Profile> profiles() { actor(); return people.profiles(); }
    public List<Trip> trips() { actor(); return rides.trips(); }
    public List<Vehicle> vehicles() { actor(); return cars.vehicles(); }
    public List<DriverLocation> locations() { actor(); return gps.locations(); }
    private Trip trip(String id) {
        return rides.trips().stream().filter(t -> t.id().equals(id)).findFirst()
                .orElseThrow(() -> new BusinessRule("Viaje no encontrado o sin acceso"));
    }
    public void createTrip(String origin, String destination) {
        var p=actor(); p.requireRole("passenger");
        var from=text(origin,3,150,"Origen"); var to=text(destination,3,150,"Destino");
        require(!from.equalsIgnoreCase(to),"Origen y destino deben ser diferentes");
        require(rides.trips().stream().noneMatch(t -> t.passenger_id().equals(p.id()) && t.active()), "Ya tienes un viaje activo");
        rides.createTrip(from,to);
    }
    public void transitionTrip(String id, String status) {
        var p=actor(); var t=trip(id); t.validateTransition(p,status);
        if (status.equals("accepted")) {
            require(cars.vehicles().stream().anyMatch(v -> v.driver_id().equals(p.id())),"Registra tu vehículo");
            require(rides.trips().stream().noneMatch(r -> p.id().equals(r.driver_id()) && r.active()),"Ya tienes un viaje activo");
        }
        // The adapter must atomically compare the stored state, to handle concurrent drivers.
        rides.transitionTrip(id,status);
    }
    public void rejectTrip(String id) {
        actor().requireRole("driver"); require(trip(id).status().equals("pending"),"Solicitud no disponible");
        rides.rejectTrip(id);
    }
    public void rateTrip(String id,int stars,String comment) {
        trip(id).validateRating(actor(),stars); rides.rateTrip(id,stars,text(comment,0,255,"Comentario"));
    }
    public void saveProfile(String name,String phone) {
        actor(); people.saveProfile(text(name,2,80,"Nombre"),text(phone,0,25,"Teléfono"));
    }
    public void setAvailability(boolean available) {
        var p=actor(); p.requireRole("driver");
        if (available) require(cars.vehicles().stream().anyMatch(v -> v.driver_id().equals(p.id())),"Registra tu vehículo");
        people.setAvailability(available);
    }
    public void setActive(String id,boolean active) {
        actor().requireRole("admin");
        var target=people.profiles().stream().filter(p -> p.id().equals(id)).findFirst().orElseThrow(() -> new BusinessRule("Usuario no encontrado"));
        require(!target.role().equals("admin"),"No se puede suspender un administrador");
        require(rides.trips().stream().noneMatch(t -> t.active() && (id.equals(t.passenger_id()) || id.equals(t.driver_id()))),"El usuario tiene un viaje activo");
        people.setActive(id,active);
    }
    public void saveVehicle(Vehicle vehicle) {
        var p=actor();
        String owner=p.id();
        if(p.role().equals("admin")) {
            require(people.profiles().stream().anyMatch(u -> u.id().equals(vehicle.driver_id()) && u.role().equals("driver")),"Conductor no encontrado");
            owner=vehicle.driver_id();
        } else { p.requireRole("driver"); }
        cars.saveVehicle(new Vehicle(owner,vehicle.plate(),vehicle.brand(),vehicle.model(),vehicle.color(),vehicle.license()).validated());
    }
    public void saveLocation(double latitude,double longitude) {
        var p=actor(); p.requireRole("driver");
        var point=new DriverLocation(p.id(),latitude,longitude,null);
        require(rides.trips().stream().anyMatch(t -> p.id().equals(t.driver_id()) && (t.status().equals("accepted") || t.status().equals("in_progress"))),"No tienes un viaje activo");
        gps.saveLocation(point);
    }
}
