package co.ridemove.domain;

import java.util.Set;

public record Trip(String id, String passenger_id, String driver_id, String origin, String destination,
                   String status, String created_at, String completed_at, Integer rating, String comment,
                   Double origin_lat, Double origin_lng, Double destination_lat, Double destination_lng,
                   Integer distance_m, Integer duration_s, Long fare_cents, String payment_method,
                   String accepted_at, String arrived_at, String started_at, String cancelled_by) {
    public static final Set<String> ACTIVE = Set.of("pending", "accepted", "arrived", "in_progress");
    public static final Set<String> ASSIGNED = Set.of("accepted", "arrived", "in_progress");
    public Trip(String id, String passenger_id, String driver_id, String origin, String destination,
                String status, String created_at, String completed_at, Integer rating, String comment) {
        this(id, passenger_id, driver_id, origin, destination, status, created_at, completed_at, rating, comment,
             null, null, null, null, null, null, null, "cash", null, null, null, null);
    }
    public boolean active() { return ACTIVE.contains(status); }
    /** pending → accepted → arrived → in_progress → completed; el pasajero cancela antes de iniciar. */
    public void validateTransition(Profile actor, String target) {
        actor.requireActive();
        boolean passengerOwner = actor.role().equals("passenger") && actor.id().equals(passenger_id);
        boolean assignedDriver = actor.role().equals("driver") && actor.id().equals(driver_id);
        boolean allowed = switch (status + ":" + target) {
            case "pending:cancelled", "accepted:cancelled", "arrived:cancelled" -> passengerOwner;
            case "pending:accepted" -> actor.role().equals("driver") && actor.available();
            case "accepted:arrived", "arrived:in_progress", "accepted:in_progress", "in_progress:completed" -> assignedDriver;
            case "accepted:pending", "arrived:pending" -> assignedDriver; // el conductor libera el viaje
            default -> false;
        };
        BusinessRule.require(allowed, "Transición no permitida para este viaje y usuario");
    }
    public void validateRating(Profile actor, int stars) {
        actor.requireRole("passenger");
        BusinessRule.require(actor.id().equals(passenger_id) && status.equals("completed") && rating == null,
                "Solo puedes calificar una vez tu propio viaje finalizado");
        BusinessRule.require(stars >= 1 && stars <= 5, "La calificación debe estar entre 1 y 5");
    }
}
