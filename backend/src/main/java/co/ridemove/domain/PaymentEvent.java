package co.ridemove.domain;

import java.util.List;

/** Evento firmado de Wompi: valores de signature.properties, timestamp y checksum recibido. */
public record PaymentEvent(String type, List<String> signedValues, long timestamp, String checksum,
                           GatewayTransaction transaction) {}
