package co.ridemove.domain;

import static co.ridemove.domain.BusinessRule.*;

/** Solicitud de viaje del pasajero. La tarifa definitiva la calcula la base de datos. */
public record TripDraft(String origin, String destination, Double originLat, Double originLng,
                        Double destinationLat, Double destinationLng, Integer distanceM, Integer durationS,
                        String paymentMethod) {
    public static TripDraft of(String origin, String destination) {
        return new TripDraft(origin, destination, null, null, null, null, null, null, "cash");
    }
    private static boolean lat(Double v) { return v != null && Double.isFinite(v) && v >= -90 && v <= 90; }
    private static boolean lng(Double v) { return v != null && Double.isFinite(v) && v >= -180 && v <= 180; }
    public TripDraft validated() {
        var from = text(origin, 3, 150, "Origen");
        var to = text(destination, 3, 150, "Destino");
        require(!from.equalsIgnoreCase(to), "Origen y destino deben ser diferentes");
        boolean anyPoint = originLat != null || originLng != null || destinationLat != null || destinationLng != null;
        if (anyPoint) require(lat(originLat) && lng(originLng) && lat(destinationLat) && lng(destinationLng), "Coordenadas del viaje inválidas");
        require(distanceM == null || (distanceM >= 0 && distanceM <= 500_000), "Distancia inválida");
        require(durationS == null || (durationS >= 0 && durationS <= 86_400), "Duración inválida");
        var method = paymentMethod == null || paymentMethod.isBlank() ? "cash" : paymentMethod.trim().toLowerCase(java.util.Locale.ROOT);
        require(method.equals("cash") || method.equals("wompi"), "Medio de pago inválido");
        return new TripDraft(from, to, originLat, originLng, destinationLat, destinationLng, distanceM, durationS, method);
    }
}
