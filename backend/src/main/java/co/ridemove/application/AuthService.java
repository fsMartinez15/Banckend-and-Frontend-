package co.ridemove.application;
import co.ridemove.application.port.in.AuthUseCases;
import co.ridemove.application.port.out.DirectoryPort;
import co.ridemove.application.port.out.IdentityPort;
import co.ridemove.domain.AuthSession;
import co.ridemove.domain.SignUp;
import static co.ridemove.domain.BusinessRule.*;

/** Authentication use cases: pure Java, independent of JWT/HTTP/Supabase SDKs. */
public final class AuthService implements AuthUseCases {
    private final IdentityPort identity;
    private final DirectoryPort directory;
    public AuthService(IdentityPort identity, DirectoryPort directory) { this.identity = identity; this.directory = directory; }
    private String email(String value) {
        var email = text(value, 3, 254, "Correo").toLowerCase(java.util.Locale.ROOT);
        require(email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"), "Correo inválido");
        return email;
    }
    private void password(String value, int minimum) {
        require(value != null && value.length() >= minimum && value.length() <= 128,
                "La contraseña debe tener entre " + minimum + " y 128 caracteres");
    }
    public AuthSession login(String identifier, String password) {
        password(password, 1);
        var value = identifier == null ? "" : identifier.trim();
        if (value.contains("@")) return identity.login(email(value), password);
        require(SignUp.looksLikeDocument(value), "Escribe tu correo o tu número de cédula");
        var found = directory.emailForDocument(SignUp.normalizeDocument(value));
        require(found != null, "Cédula o contraseña incorrectas");
        return identity.login(found, password);
    }
    public AuthSession register(String email, String password, String name, String role,
                                String documentType, String documentNumber, String phone) {
        password(password, 8);
        var data = SignUp.of(email(email), password, name, role, documentType, documentNumber, phone);
        if (data.documentNumber() != null)
            require(!directory.documentRegistered(data.documentNumber()), "Ya existe una cuenta con ese número de documento");
        return identity.register(data);
    }
    public AuthSession refresh(String token) { return identity.refresh(text(token, 1, 4096, "Sesión de renovación")); }
    public void logout(String token) { identity.logout(token); }
}
