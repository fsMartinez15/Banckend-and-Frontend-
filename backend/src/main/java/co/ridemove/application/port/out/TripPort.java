package co.ridemove.application.port.out;
import co.ridemove.domain.Trip;
import java.util.List;

public interface TripPort {
    List<Trip> trips();
    void createTrip(String origin, String destination);
    void transitionTrip(String id, String status);
    void rejectTrip(String id);
    void rateTrip(String id, int rating, String comment);
}
