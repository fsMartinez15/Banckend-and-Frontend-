package co.ridemove.domain;

public record DriverLocation(String driver_id, double latitude, double longitude, String updated_at) {
    public DriverLocation {
        BusinessRule.require(Double.isFinite(latitude) && latitude >= -90 && latitude <= 90 &&
                Double.isFinite(longitude) && longitude >= -180 && longitude <= 180, "Coordenadas inválidas");
    }
}
