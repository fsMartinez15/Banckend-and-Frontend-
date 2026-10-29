package co.ridemove.domain;

/** Tarifa tipo Uber: banderazo + kilómetros + minutos, con mínima. Valores en centavos de COP. */
public record Tariff(long base_cents, long per_km_cents, long per_min_cents, long minimum_cents) {
    public long estimate(int meters, int seconds) {
        double raw = base_cents + per_km_cents * Math.max(meters, 0) / 1000.0 + per_min_cents * Math.max(seconds, 0) / 60.0;
        long rounded = Math.round(raw / 10_000.0) * 10_000; // centena de pesos
        return Math.max(minimum_cents, rounded);
    }
}
