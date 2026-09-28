package co.ridemove.adapter.out;
import co.ridemove.application.port.out.IdentityPort;
import co.ridemove.domain.AuthSession;
import org.springframework.web.client.RestClient;

public final class SupabaseIdentityAdapter implements IdentityPort {
    private final RestClient client;
    public SupabaseIdentityAdapter(RestClient client) { this.client = client; }
    record Credentials(String email, String password) {}
    record Metadata(String name, String role) {}
    record Registration(String email, String password, Metadata data) {}
    record Refresh(String refresh_token) {}
    public AuthSession login(String email, String password) {
        return client.post().uri("/auth/v1/token?grant_type=password")
                .body(new Credentials(email,password)).retrieve().body(AuthSession.class);
    }
    public AuthSession register(String email, String password, String name, String role) {
        return client.post().uri("/auth/v1/signup").body(new Registration(email,password,new Metadata(name,role)))
                .retrieve().body(AuthSession.class);
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
