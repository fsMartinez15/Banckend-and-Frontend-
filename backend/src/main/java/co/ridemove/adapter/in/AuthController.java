package co.ridemove.adapter.in;
import co.ridemove.application.port.in.AuthUseCases;
import co.ridemove.domain.AuthSession;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;

@RestController @RequestMapping("/api/auth")
public class AuthController {
    private final AuthUseCases auth;
    public AuthController(AuthUseCases auth) { this.auth = auth; }
    public record Login(String email, String password) {}
    public record Register(String email, String password, String name, String role) {}
    public record Refresh(String refreshToken) {}
    @PostMapping("/login") public AuthSession login(@RequestBody Login body) { return auth.login(body.email(),body.password()); }
    @PostMapping("/register") @ResponseStatus(HttpStatus.CREATED)
    public AuthSession register(@RequestBody Register body) { return auth.register(body.email(),body.password(),body.name(),body.role()); }
    @PostMapping("/refresh") public AuthSession refresh(@RequestBody Refresh body) { return auth.refresh(body.refreshToken()); }
    @PostMapping("/logout") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@AuthenticationPrincipal Jwt token) { auth.logout(token.getTokenValue()); }
}
