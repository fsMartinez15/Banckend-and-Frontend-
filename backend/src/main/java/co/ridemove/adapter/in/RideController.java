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
    public record Route(String origin,String destination) {}
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
    public void create(@RequestBody Route body) { app.createTrip(body.origin(),body.destination()); }
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
