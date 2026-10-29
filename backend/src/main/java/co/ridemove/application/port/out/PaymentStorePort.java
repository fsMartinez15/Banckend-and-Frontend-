package co.ridemove.application.port.out;
import co.ridemove.domain.Payment;
import java.util.Optional;

public interface PaymentStorePort {
    void create(Payment payment);
    Optional<Payment> byReference(String reference);
    boolean approvedForTrip(String tripId);
    void update(String reference, String status, String transactionId, String method);
}
