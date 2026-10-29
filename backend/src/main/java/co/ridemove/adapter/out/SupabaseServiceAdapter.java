package co.ridemove.adapter.out;

import co.ridemove.application.port.out.DirectoryPort;
import co.ridemove.application.port.out.PaymentStorePort;
import co.ridemove.domain.BusinessRule;
import co.ridemove.domain.Payment;
import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.web.client.RestClient;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * Adaptador con la clave secreta (service_role) de Supabase. Solo existe en el servidor:
 * resuelve la cédula al iniciar sesión y escribe pagos confirmados por Wompi.
 * Si la clave no está configurada, estas funciones responden con un mensaje claro.
 */
public final class SupabaseServiceAdapter implements DirectoryPort, PaymentStorePort {
    private final RestClient api;
    public SupabaseServiceAdapter(RestClient api) { this.api = api; }
    private RestClient api() {
        if (api == null) throw new BusinessRule("Falta SUPABASE_SERVICE_KEY en el backend: el inicio con cédula y los pagos están desactivados");
        return api;
    }
    private static String q(String v) { return URLEncoder.encode(v, StandardCharsets.UTF_8); }
    private JsonNode rpc(String name, Map<String, Object> args) {
        return api().post().uri("/rest/v1/rpc/" + name).body(args).retrieve().body(JsonNode.class);
    }
    public String emailForDocument(String documentNumber) {
        var result = rpc("login_email", Map.of("p_document", documentNumber));
        return result == null || result.isNull() ? null : result.asText();
    }
    public boolean documentRegistered(String documentNumber) {
        var result = rpc("document_registered", Map.of("p_document", documentNumber));
        return result != null && result.asBoolean(false);
    }
    public void create(Payment p) {
        var row = new LinkedHashMap<String, Object>();
        row.put("trip_id", p.trip_id()); row.put("passenger_id", p.passenger_id()); row.put("reference", p.reference());
        row.put("amount_in_cents", p.amount_in_cents()); row.put("currency", p.currency()); row.put("status", p.status());
        api().post().uri("/rest/v1/payments").header("Prefer", "return=minimal").body(row).retrieve().toBodilessEntity();
    }
    public Optional<Payment> byReference(String reference) {
        var rows = api().get().uri("/rest/v1/payments?reference=eq." + q(reference) + "&limit=1").retrieve().body(Payment[].class);
        return rows == null || rows.length == 0 ? Optional.empty() : Optional.of(rows[0]);
    }
    public boolean approvedForTrip(String tripId) {
        var rows = api().get().uri("/rest/v1/payments?select=id&status=eq.APPROVED&trip_id=eq." + q(tripId) + "&limit=1").retrieve().body(JsonNode.class);
        return rows != null && rows.size() > 0;
    }
    public void update(String reference, String status, String transactionId, String method) {
        var row = new HashMap<String, Object>();
        row.put("status", status); row.put("wompi_transaction_id", transactionId); row.put("payment_method", method);
        row.put("updated_at", java.time.OffsetDateTime.now().toString());
        api().patch().uri("/rest/v1/payments?reference=eq." + q(reference) + "&status=neq.APPROVED")
             .header("Prefer", "return=minimal").body(row).retrieve().toBodilessEntity();
    }
}
