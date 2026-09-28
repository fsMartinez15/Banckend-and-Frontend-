package co.ridemove.application.port.out;
import co.ridemove.domain.Vehicle;
import java.util.List;
public interface VehiclePort {
    List<Vehicle> vehicles();
    void saveVehicle(Vehicle vehicle);
}
