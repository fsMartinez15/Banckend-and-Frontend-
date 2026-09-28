package co.ridemove.application.port.out;
import co.ridemove.domain.AuthSession;

public interface IdentityPort {
    AuthSession login(String email, String password);
    AuthSession register(String email, String password, String name, String role);
    AuthSession refresh(String refreshToken);
    void logout(String accessToken);
}
