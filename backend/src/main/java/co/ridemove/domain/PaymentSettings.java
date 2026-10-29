package co.ridemove.domain;

/** Configuración de cobro. Los secretos viven solo en el backend. */
public record PaymentSettings(String publicKey, String integritySecret, String eventsSecret,
                              String checkoutUrl, String redirectUrl, long fareInCents) {
    public boolean configured() {
        return notBlank(publicKey) && notBlank(integritySecret) && fareInCents > 0;
    }
    private static boolean notBlank(String v) { return v != null && !v.isBlank(); }
}
