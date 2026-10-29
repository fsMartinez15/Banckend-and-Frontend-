package co.ridemove.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/** Firmas SHA-256 de Wompi (integridad del checkout y checksum de eventos). */
public final class PaymentSignature {
    private PaymentSignature() {}
    public static String sha256(String value) {
        try {
            var digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
    /** SHA256(referencia + monto en centavos + moneda + secreto de integridad). */
    public static String integrity(String reference, long amountInCents, String currency, String integritySecret) {
        return sha256(reference + amountInCents + currency + integritySecret);
    }
    /** SHA256(valores de signature.properties en orden + timestamp + secreto de eventos). */
    public static String eventChecksum(Iterable<String> values, long timestamp, String eventsSecret) {
        var text = new StringBuilder();
        for (var v : values) text.append(v == null ? "" : v);
        return sha256(text.append(timestamp).append(eventsSecret).toString());
    }
    public static boolean sameChecksum(String expected, String received) {
        if (expected == null || received == null) return false;
        return MessageDigest.isEqual(expected.toLowerCase().getBytes(StandardCharsets.UTF_8),
                                     received.trim().toLowerCase().getBytes(StandardCharsets.UTF_8));
    }
}
