package co.ridemove.adapter.in;

import co.ridemove.adapter.out.WompiHttpAdapter;
import co.ridemove.application.port.in.PaymentUseCases;
import co.ridemove.application.port.in.RideUseCases;
import co.ridemove.domain.*;
import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@RestController @RequestMapping("/api/payments")
public class PaymentController {
    private final PaymentUseCases payments;
    private final RideUseCases rides;
    public PaymentController(PaymentUseCases payments, RideUseCases rides) { this.payments = payments; this.rides = rides; }
    public record Checkout(String tripId) {}
    public record Confirm(String transactionId) {}
    public record Result(String reference, String status, long amount_in_cents, String currency, String payment_method) {}

    /** Pagos visibles para el usuario (RLS de Supabase). */
    @GetMapping public List<Payment> mine() { return rides.payments(); }

    @PostMapping("/checkout") public CheckoutLink checkout(@RequestBody Checkout body, @AuthenticationPrincipal Jwt jwt) {
        BusinessRule.require(body.tripId() != null, "Falta el viaje");
        var trip = rides.trips().stream().filter(t -> t.id().equals(body.tripId())).findFirst().orElse(null);
        return payments.checkout(rides.profile(), jwt.getClaimAsString("email"), trip);
    }

    /** Retorno del Web Checkout (?id=...). Público: solo sincroniza con Wompi y devuelve el estado. */
    @PostMapping("/confirm") public Result confirm(@RequestBody Confirm body) {
        var p = payments.sync(body.transactionId());
        return new Result(p.reference(), p.status(), p.amount_in_cents(), p.currency(), p.payment_method());
    }

    /** URL de eventos para configurar en el panel de Wompi. Siempre 200 para eventos válidos. */
    @PostMapping("/wompi/events") public ResponseEntity<?> events(@RequestBody JsonNode body,
                                                                 @RequestHeader(value = "X-Event-Checksum", required = false) String header) {
        var signature = body.path("signature");
        var data = body.path("data");
        var values = new ArrayList<String>();
        for (var property : signature.path("properties")) {
            var node = data;
            for (var part : property.asText().split("\\.")) node = node.path(part);
            values.add(node.isMissingNode() || node.isNull() ? "" : node.asText());
        }
        long timestamp = body.has("timestamp") ? body.path("timestamp").asLong() : signature.path("timestamp").asLong();
        var checksum = header != null && !header.isBlank() ? header : signature.path("checksum").asText(null);
        var event = new PaymentEvent(body.path("event").asText(null), values, timestamp, checksum,
                WompiHttpAdapter.parse(data.path("transaction")));
        boolean accepted = payments.handleEvent(event);
        return accepted ? ResponseEntity.ok(Map.of("received", true)) : ResponseEntity.status(400).body(Map.of("received", false));
    }
}
