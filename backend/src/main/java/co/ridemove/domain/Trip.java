package co.ridemove.domain;

public record Trip(String id, String passenger_id, String driver_id, String origin, String destination,
                   String status, String created_at, String completed_at, Integer rating, String comment) {
    public boolean active() { return status.equals("pending") || status.equals("accepted") || status.equals("in_progress"); }
    public void validateTransition(Profile actor, String target) {
        actor.requireActive();
        boolean allowed = switch (status + ":" + target) {
            case "pending:cancelled" -> actor.role().equals("passenger") && actor.id().equals(passenger_id);
            case "pending:accepted" -> actor.role().equals("driver") && actor.available();
            case "accepted:in_progress", "in_progress:completed" -> actor.role().equals("driver") && actor.id().equals(driver_id);
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
