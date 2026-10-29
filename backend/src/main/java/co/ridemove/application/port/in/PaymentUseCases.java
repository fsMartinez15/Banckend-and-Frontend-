package co.ridemove.application.port.in;
import co.ridemove.domain.*;

public interface PaymentUseCases {
    /** Crea un intento de pago y devuelve el enlace firmado del Web Checkout de Wompi. */
    CheckoutLink checkout(Profile payer, String email, Trip trip);
    /** Procesa un evento firmado de Wompi. Devuelve false si se ignora (firma o referencia inválida). */
    boolean handleEvent(PaymentEvent event);
    /** Consulta la transacción en Wompi y actualiza el pago (retorno del checkout). */
    Payment sync(String transactionId);
}
