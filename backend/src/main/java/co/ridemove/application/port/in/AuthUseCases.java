package co.ridemove.application.port.in;
import co.ridemove.domain.AuthSession;

public interface AuthUseCases {
    AuthSession login(String email, String password);
    AuthSession register(String email, String password, String name, String role);
    AuthSession refresh(String refreshToken);
    void logout(String accessToken);
}
