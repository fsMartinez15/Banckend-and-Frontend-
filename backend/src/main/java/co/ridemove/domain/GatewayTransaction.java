package co.ridemove.domain;

/** Transacción tal como la reporta la pasarela (Wompi). */
public record GatewayTransaction(String id, String reference, String status, long amount_in_cents,
                                 String currency, String payment_method_type) {}
