package co.ridemove.adapter.out;
import co.ridemove.application.port.out.IdentityPort;
import co.ridemove.domain.AuthSession;
import co.ridemove.domain.BusinessRule;
import co.ridemove.domain.SignUp;
import com.fasterxml.jackson.annotation.JsonInclude;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

public final class SupabaseIdentityAdapter implements IdentityPort {
    private final RestClient client;
    public SupabaseIdentityAdapter(RestClient client) { this.client = client; }
    record Credentials(String email, String password) {}
    @JsonInclude(JsonInclude.Include.NON_NULL)
    record Metadata(String name, String role, String document_type, String document_number, String phone) {}
    record Registration(String email, String password, Metadata data) {}
    record Refresh(String refresh_token) {}
    public AuthSession login(String email, String password) {
        try {
            return client.post().uri("/auth/v1/token?grant_type=password")
                    .body(new Credentials(email,password)).retrieve().body(AuthSession.class);
        } catch (RestClientResponseException e) {
            var body = e.getResponseBodyAsString();
            if (body.contains("email_not_confirmed")) throw new BusinessRule("Confirma tu correo antes de iniciar sesión");
            if (e.getStatusCode().value() == 400) throw new BusinessRule("Correo, cédula o contraseña incorrectos");
            throw e;
        }
    }
    public AuthSession register(SignUp d) {
        try {
            return client.post().uri("/auth/v1/signup").body(new Registration(d.email(), d.password(),
                    new Metadata(d.name(), d.role(), d.documentType(), d.documentNumber(), d.phone())))
                    .retrieve().body(AuthSession.class);
        } catch (RestClientResponseException e) {
            var body = e.getResponseBodyAsString();
            if (body.contains("user_already_exists") || body.contains("already registered")) throw new BusinessRule("Ese correo ya está registrado");
            if (body.contains("weak_password")) throw new BusinessRule("La contraseña es muy débil. Usa letras, números y símbolos");
            if (e.getStatusCode().value() == 500) throw new BusinessRule("No se pudo crear la cuenta. Verifica que el documento no esté registrado");
            throw e;
        }
    }
    public AuthSession refresh(String token) {
        return client.post().uri("/auth/v1/token?grant_type=refresh_token").body(new Refresh(token))
                .retrieve().body(AuthSession.class);
    }
    public void logout(String token) {
        client.post().uri("/auth/v1/logout?scope=local").header("Authorization", "Bearer " + token)
                .retrieve().toBodilessEntity();
    }
}
