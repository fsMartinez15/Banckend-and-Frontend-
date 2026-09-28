package co.ridemove.application.port.out;
import co.ridemove.domain.DriverLocation;
import java.util.List;
public interface LocationPort {
    List<DriverLocation> locations();
    void saveLocation(DriverLocation location);
}
