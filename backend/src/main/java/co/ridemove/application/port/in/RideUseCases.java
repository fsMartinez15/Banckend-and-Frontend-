package co.ridemove.application.port.in;
import co.ridemove.domain.*;
import java.util.List;

public interface RideUseCases {
    Profile profile();
    List<Profile> profiles();
    List<Trip> trips();
    List<Vehicle> vehicles();
    List<DriverLocation> locations();
    void createTrip(String origin, String destination);
    void transitionTrip(String id, String status);
    void rejectTrip(String id);
    void rateTrip(String id, int stars, String comment);
    void saveProfile(String name, String phone);
    void setAvailability(boolean available);
    void setActive(String id, boolean active);
    void saveVehicle(Vehicle vehicle);
    void saveLocation(double latitude, double longitude);
}
