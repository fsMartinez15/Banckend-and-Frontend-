package co.ridemove.application.port.out;
import co.ridemove.domain.AuthSession;
import co.ridemove.domain.SignUp;

public interface IdentityPort {
    AuthSession login(String email, String password);
    AuthSession register(SignUp data);
    AuthSession refresh(String refreshToken);
    void logout(String accessToken);
}
