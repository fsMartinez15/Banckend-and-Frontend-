package co.ridemove.application.port.in;
import co.ridemove.domain.AuthSession;

public interface AuthUseCases {
    /** identifier: correo electrónico o número de cédula. */
    AuthSession login(String identifier, String password);
    AuthSession register(String email, String password, String name, String role,
                         String documentType, String documentNumber, String phone);
    AuthSession refresh(String refreshToken);
    void logout(String accessToken);
}
