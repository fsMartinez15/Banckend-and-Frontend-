package co.ridemove.adapter.out;

import co.ridemove.application.port.out.PaymentGatewayPort;
import co.ridemove.domain.BusinessRule;
import co.ridemove.domain.GatewayTransaction;
import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.web.client.RestClient;

/** Consulta de transacciones en la API de Wompi (https://production.wompi.co/v1). */
public final class WompiHttpAdapter implements PaymentGatewayPort {
    private final RestClient api;
    public WompiHttpAdapter(RestClient api) { this.api = api; }
    public static GatewayTransaction parse(JsonNode tx) {
        if (tx == null || tx.isMissingNode() || tx.isNull()) return null;
        return new GatewayTransaction(tx.path("id").asText(null), tx.path("reference").asText(null), tx.path("status").asText(null),
                tx.path("amount_in_cents").asLong(-1), tx.path("currency").asText(null), tx.path("payment_method_type").asText(null));
    }
    public GatewayTransaction transaction(String id) {
        var body = api.get().uri("/transactions/{id}", id).retrieve().body(JsonNode.class);
        var tx = parse(body == null ? null : body.path("data"));
        if (tx == null) throw new BusinessRule("Wompi no devolvió la transacción");
        return tx;
    }
}
