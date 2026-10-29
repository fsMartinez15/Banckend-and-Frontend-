package co.ridemove.domain;

/** Intento de pago de un viaje. El estado lo decide Wompi; nunca el navegador. */
public record Payment(String id, String trip_id, String passenger_id, String reference, long amount_in_cents,
                      String currency, String status, String wompi_transaction_id, String payment_method,
                      String created_at, String updated_at) {
    public boolean approved() { return "APPROVED".equals(status); }
    /** Estados de transacción de Wompi admitidos en la tabla de pagos. */
    public static String normalizeStatus(String wompiStatus) {
        if (wompiStatus == null) return "PENDING";
        return switch (wompiStatus.toUpperCase(java.util.Locale.ROOT)) {
            case "APPROVED" -> "APPROVED";
            case "DECLINED" -> "DECLINED";
            case "VOIDED" -> "VOIDED";
            case "ERROR" -> "ERROR";
            default -> "PENDING";
        };
    }
}
