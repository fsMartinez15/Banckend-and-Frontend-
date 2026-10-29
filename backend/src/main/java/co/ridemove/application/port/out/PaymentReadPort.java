package co.ridemove.application.port.out;
import co.ridemove.domain.Payment;
import java.util.List;

/** Lectura de pagos con la sesión del usuario (respeta RLS). */
public interface PaymentReadPort {
    List<Payment> payments();
}
