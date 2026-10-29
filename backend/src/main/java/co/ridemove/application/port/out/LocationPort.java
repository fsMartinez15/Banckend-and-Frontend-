package co.ridemove.application.port.out;
import co.ridemove.domain.DriverLocation;
import co.ridemove.domain.NearbyDriver;
import java.util.List;
public interface LocationPort {
    List<DriverLocation> locations();
    void saveLocation(DriverLocation location);
    List<NearbyDriver> nearbyDrivers(double latitude, double longitude);
}
