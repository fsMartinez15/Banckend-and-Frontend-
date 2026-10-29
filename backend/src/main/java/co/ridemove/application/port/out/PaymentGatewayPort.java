package co.ridemove.application.port.out;
import co.ridemove.domain.GatewayTransaction;

public interface PaymentGatewayPort {
    GatewayTransaction transaction(String transactionId);
}
