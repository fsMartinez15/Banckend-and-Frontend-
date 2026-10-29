package co.ridemove.application;

import co.ridemove.application.port.in.PaymentUseCases;
import co.ridemove.application.port.out.PaymentGatewayPort;
import co.ridemove.application.port.out.PaymentStorePort;
import co.ridemove.domain.*;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.stream.Collectors;
import static co.ridemove.domain.BusinessRule.require;

/** Cobro de viajes con el Web Checkout de Wompi. Pure Java. */
public final class PaymentService implements PaymentUseCases {
    private static final String CURRENCY = "COP";
    private static final SecureRandom RANDOM = new SecureRandom();
    private final PaymentStorePort store;
    private final PaymentGatewayPort gateway;
    private final PaymentSettings settings;
    public PaymentService(PaymentStorePort store, PaymentGatewayPort gateway, PaymentSettings settings) {
        this.store = store; this.gateway = gateway; this.settings = settings;
    }
    private static String enc(String v) { return URLEncoder.encode(v, StandardCharsets.UTF_8); }
    private static String reference(String tripId) {
        var random = Long.toString(Math.abs(RANDOM.nextLong()), 36).toUpperCase(Locale.ROOT);
        var shortTrip = tripId.replace("-", "").substring(0, Math.min(8, tripId.replace("-", "").length())).toUpperCase(Locale.ROOT);
        return "RM-" + shortTrip + "-" + Long.toString(System.currentTimeMillis(), 36).toUpperCase(Locale.ROOT) + "-" + random.substring(0, Math.min(6, random.length()));
    }

    public CheckoutLink checkout(Profile payer, String email, Trip trip) {
        require(settings.configured(), "Los pagos con Wompi no están configurados en el servidor");
        payer.requireRole("passenger");
        require(trip != null, "Viaje no encontrado o sin acceso");
        require(payer.id().equals(trip.passenger_id()), "Solo puedes pagar tus propios viajes");
        require("completed".equals(trip.status()), "Solo se pueden pagar viajes finalizados");
        require(!store.approvedForTrip(trip.id()), "Este viaje ya está pagado");
        var reference = reference(trip.id());
        long amount = trip.fare_cents() != null && trip.fare_cents() > 0 ? trip.fare_cents() : settings.fareInCents();
        store.create(new Payment(null, trip.id(), payer.id(), reference, amount, CURRENCY, "PENDING", null, null, null, null));

        var params = new LinkedHashMap<String, String>();
        params.put("public-key", settings.publicKey());
        params.put("currency", CURRENCY);
        params.put("amount-in-cents", Long.toString(amount));
        params.put("reference", reference);
        params.put("signature:integrity", PaymentSignature.integrity(reference, amount, CURRENCY, settings.integritySecret()));
        if (settings.redirectUrl() != null && !settings.redirectUrl().isBlank()) params.put("redirect-url", settings.redirectUrl());
        if (email != null && !email.isBlank()) params.put("customer-data:email", email);
        params.put("customer-data:full-name", payer.name());
        if (payer.document_number() != null) {
            params.put("customer-data:legal-id", payer.document_number());
            params.put("customer-data:legal-id-type", payer.document_type() == null ? "CC" : payer.document_type());
        }
        var phone = payer.phone() == null ? "" : payer.phone().replaceAll("\\D", "");
        if (phone.length() == 10) { params.put("customer-data:phone-number", phone); params.put("customer-data:phone-number-prefix", "+57"); }
        var query = params.entrySet().stream().map(e -> enc(e.getKey()) + "=" + enc(e.getValue())).collect(Collectors.joining("&"));
        return new CheckoutLink(settings.checkoutUrl() + "?" + query, reference, amount, CURRENCY);
    }

    private Payment apply(GatewayTransaction tx) {
        if (tx == null || tx.reference() == null) return null;
        var payment = store.byReference(tx.reference()).orElse(null);
        if (payment == null) return null;
        // Un monto o moneda distintos al intento creado nunca aprueban el viaje.
        boolean matches = tx.amount_in_cents() == payment.amount_in_cents() && CURRENCY.equals(tx.currency());
        var status = matches ? Payment.normalizeStatus(tx.status()) : "ERROR";
        if (payment.approved()) return payment; // Un pago aprobado no retrocede.
        store.update(payment.reference(), status, tx.id(), tx.payment_method_type());
        return new Payment(payment.id(), payment.trip_id(), payment.passenger_id(), payment.reference(), payment.amount_in_cents(),
                payment.currency(), status, tx.id(), tx.payment_method_type(), payment.created_at(), payment.updated_at());
    }

    public boolean handleEvent(PaymentEvent event) {
        if (event == null || settings.eventsSecret() == null || settings.eventsSecret().isBlank()) return false;
        var expected = PaymentSignature.eventChecksum(event.signedValues(), event.timestamp(), settings.eventsSecret());
        if (!PaymentSignature.sameChecksum(expected, event.checksum())) return false;
        // Firma válida: se responde 200 aunque la referencia no sea de RideMove, para que Wompi no reintente.
        if ("transaction.updated".equals(event.type())) apply(event.transaction());
        return true;
    }

    public Payment sync(String transactionId) {
        require(transactionId != null && transactionId.matches("^[A-Za-z0-9-]{5,64}$"), "Transacción inválida");
        var payment = apply(gateway.transaction(transactionId));
        require(payment != null, "No encontramos un pago de RideMove para esta transacción");
        return payment;
    }
}
