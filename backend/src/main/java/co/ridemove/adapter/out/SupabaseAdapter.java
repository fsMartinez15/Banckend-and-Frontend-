package co.ridemove.adapter.out;

import co.ridemove.application.port.out.*;
import co.ridemove.domain.*;
import org.springframework.web.client.RestClient;
import java.util.*;

/** User-scoped adapter: forwards the verified access token, preserving PostgreSQL RLS. */
public final class SupabaseAdapter implements ProfilePort, TripPort, VehiclePort, LocationPort, PaymentReadPort {
    private final RestClient api;
    private final String userId;
    public SupabaseAdapter(RestClient api, String userId) { this.api=api; this.userId=userId; }
    private <T> List<T> list(String path,Class<T[]> type) {
        var result=api.get().uri("/rest/v1/"+path).retrieve().body(type);
        return result==null ? List.of() : Arrays.asList(result);
    }
    private void rpc(String name,Map<String,Object> args) { api.post().uri("/rest/v1/rpc/"+name).body(args).retrieve().toBodilessEntity(); }
    public Profile currentProfile() { return list("profiles?id=eq."+userId,Profile[].class).stream().findFirst().orElseThrow(() -> new BusinessRule("Perfil no encontrado")); }
    public List<Profile> profiles() { return list("profiles?order=name",Profile[].class); }
    public List<Trip> trips() { return list("trips?order=created_at.desc",Trip[].class); }
    public List<Vehicle> vehicles() { return list("vehicles",Vehicle[].class); }
    public List<DriverLocation> locations() { return list("locations",DriverLocation[].class); }
    public List<Payment> payments() { return list("payments?order=created_at.desc",Payment[].class); }
    public void requestTrip(TripDraft d) {
        var args=new HashMap<String,Object>();
        args.put("p_origin",d.origin()); args.put("p_destination",d.destination());
        args.put("p_origin_lat",d.originLat()); args.put("p_origin_lng",d.originLng());
        args.put("p_destination_lat",d.destinationLat()); args.put("p_destination_lng",d.destinationLng());
        args.put("p_distance_m",d.distanceM()); args.put("p_duration_s",d.durationS()); args.put("p_payment_method",d.paymentMethod());
        rpc("request_trip",args);
    }
    public Tariff tariff() {
        return list("tariff?select=base_cents,per_km_cents,per_min_cents,minimum_cents",Tariff[].class).stream().findFirst()
                .orElse(new Tariff(350000,110000,25000,600000));
    }
    public List<NearbyDriver> nearbyDrivers(double latitude,double longitude) {
        var result=api.post().uri("/rest/v1/rpc/nearby_drivers").body(Map.of("p_lat",latitude,"p_lng",longitude)).retrieve().body(NearbyDriver[].class);
        return result==null ? List.of() : Arrays.asList(result);
    }
    public void transitionTrip(String id,String status) { rpc("transition_trip",Map.of("p_id",id,"p_status",status)); }
    public void rejectTrip(String id) { rpc("reject_trip",Map.of("p_id",id)); }
    public void rateTrip(String id,int stars,String comment) { rpc("rate_trip",Map.of("p_id",id,"p_rating",stars,"p_comment",comment)); }
    public void saveProfile(String name,String phone) { rpc("save_profile",Map.of("p_name",name,"p_phone",phone)); }
    public void setAvailability(boolean available) { rpc("set_availability",Map.of("p_available",available)); }
    public void setActive(String id,boolean active) { rpc("admin_set_active",Map.of("p_id",id,"p_active",active)); }
    public void saveVehicle(Vehicle v) {
        var args=new HashMap<String,Object>(Map.of("p_plate",v.plate(),"p_brand",v.brand(),"p_model",v.model(),"p_color",v.color(),"p_license",v.license()));
        if (!v.driver_id().equals(userId)) { args.put("p_driver_id",v.driver_id()); rpc("admin_save_vehicle",args); }
        else { rpc("save_vehicle",args); }
    }
    public void saveLocation(DriverLocation p) { rpc("save_location",Map.of("p_latitude",p.latitude(),"p_longitude",p.longitude())); }
}
