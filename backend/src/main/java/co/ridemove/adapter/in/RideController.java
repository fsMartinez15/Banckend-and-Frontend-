package co.ridemove.adapter.in;

import co.ridemove.application.port.in.RideUseCases;
import co.ridemove.domain.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import java.util.List;

@RestController @RequestMapping("/api")
public class RideController {
    private final RideUseCases app;
    public RideController(RideUseCases app) { this.app=app; }
    public record Route(String origin,String destination,Double origin_lat,Double origin_lng,Double destination_lat,
                        Double destination_lng,Integer distance_m,Integer duration_s,String payment_method) {}
    public record State(String status) {}
    public record Rating(Integer rating,String comment) {}
    public record Person(String name,String phone) {}
    public record Availability(Boolean available) {}
    public record Access(Boolean active) {}
    public record Position(Double latitude,Double longitude) {}
    @GetMapping("/profile") public Profile profile() { return app.profile(); }
    @GetMapping("/profiles") public List<Profile> profiles() { return app.profiles(); }
    @GetMapping("/trips") public List<Trip> trips() { return app.trips(); }
    @GetMapping("/vehicles") public List<Vehicle> vehicles() { return app.vehicles(); }
    @GetMapping("/locations") public List<DriverLocation> locations() { return app.locations(); }
    @PostMapping("/trips") @ResponseStatus(HttpStatus.CREATED)
    public void create(@RequestBody Route body) {
        app.requestTrip(new TripDraft(body.origin(),body.destination(),body.origin_lat(),body.origin_lng(),body.destination_lat(),
                body.destination_lng(),body.distance_m(),body.duration_s(),body.payment_method()));
    }
    @GetMapping("/tariff") public Tariff tariff() { return app.tariff(); }
    @GetMapping("/drivers/nearby") public List<NearbyDriver> nearby(@RequestParam double lat,@RequestParam double lng) { return app.nearbyDrivers(lat,lng); }
    @PutMapping("/trips/{id}/status") public void transition(@PathVariable String id,@RequestBody State body) { app.transitionTrip(id,body.status()); }
    @PostMapping("/trips/{id}/rejections") public void reject(@PathVariable String id) { app.rejectTrip(id); }
    @PostMapping("/trips/{id}/rating") public void rate(@PathVariable String id,@RequestBody Rating body) {
        BusinessRule.require(body.rating()!=null,"Falta la calificación"); app.rateTrip(id,body.rating(),body.comment());
    }
    @PutMapping("/profile") public void profile(@RequestBody Person body) { app.saveProfile(body.name(),body.phone()); }
    @PutMapping("/availability") public void availability(@RequestBody Availability body) {
        BusinessRule.require(body.available()!=null,"Falta disponibilidad"); app.setAvailability(body.available());
    }
    @PutMapping("/profiles/{id}/access") public void access(@PathVariable String id,@RequestBody Access body) {
        BusinessRule.require(body.active()!=null,"Falta estado de cuenta"); app.setActive(id,body.active());
    }
    @PutMapping("/vehicle") public void vehicle(@RequestBody Vehicle body) { app.saveVehicle(body); }
    @PutMapping("/location") public void location(@RequestBody Position body) {
        BusinessRule.require(body.latitude()!=null && body.longitude()!=null,"Faltan coordenadas"); app.saveLocation(body.latitude(),body.longitude());
    }
}
