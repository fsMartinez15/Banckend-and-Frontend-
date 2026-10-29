package co.ridemove.application.port.out;
import co.ridemove.domain.Tariff;
import co.ridemove.domain.Trip;
import co.ridemove.domain.TripDraft;
import java.util.List;

public interface TripPort {
    List<Trip> trips();
    void requestTrip(TripDraft draft);
    void transitionTrip(String id, String status);
    void rejectTrip(String id);
    void rateTrip(String id, int rating, String comment);
    Tariff tariff();
}
