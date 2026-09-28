package co.ridemove.application;
import co.ridemove.application.port.in.AuthUseCases;
import co.ridemove.application.port.out.IdentityPort;
import co.ridemove.domain.AuthSession;
import static co.ridemove.domain.BusinessRule.*;

/** Authentication use cases: pure Java, independent of JWT/HTTP/Supabase SDKs. */
public final class AuthService implements AuthUseCases {
    private final IdentityPort identity;
    public AuthService(IdentityPort identity) { this.identity = identity; }
    private String email(String value) {
        var email = text(value, 3, 254, "Correo").toLowerCase(java.util.Locale.ROOT);
        require(email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"), "Correo inválido");
        return email;
    }
    private void password(String value, int minimum) {
        require(value != null && value.length() >= minimum && value.length() <= 128,
                "La contraseña debe tener entre " + minimum + " y 128 caracteres");
    }
    public AuthSession login(String email, String password) {
        password(password, 1);
        return identity.login(email(email), password);
    }
    public AuthSession register(String email, String password, String name, String role) {
        password(password, 8);
        require("passenger".equals(role) || "driver".equals(role), "Rol de registro inválido");
        return identity.register(email(email), password, text(name, 2, 80, "Nombre"), role);
    }
    public AuthSession refresh(String token) { return identity.refresh(text(token, 1, 4096, "Sesión de renovación")); }
    public void logout(String token) { identity.logout(token); }
}
