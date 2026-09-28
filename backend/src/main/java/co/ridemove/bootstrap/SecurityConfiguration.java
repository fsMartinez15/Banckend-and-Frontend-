package co.ridemove.bootstrap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.*;
import java.util.*;

@Configuration
public class SecurityConfiguration {
    @Bean JwtDecoder jwtDecoder(@Value("${ridemove.jwt-issuer}") String issuer,
                                @Value("${ridemove.jwt-jwks}") String jwks,
                                @Value("${ridemove.jwt-audience}") String audience) {
        var decoder = NimbusJwtDecoder.withJwkSetUri(jwks)
                .jwsAlgorithms(algorithms -> { algorithms.add(SignatureAlgorithm.ES256); algorithms.add(SignatureAlgorithm.RS256); })
                .build();
        decoder.setJwtValidator(validators(issuer,audience));
        return decoder;
    }
    public static OAuth2TokenValidator<Jwt> validators(String issuer, String audience) {
        OAuth2TokenValidator<Jwt> claims = token -> {
            try {
                UUID.fromString(token.getSubject());
                if (token.getExpiresAt() != null && token.getAudience().contains(audience)) return OAuth2TokenValidatorResult.success();
            } catch (RuntimeException ignored) { /* Reject malformed identity claims. */ }
            return OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token", "Sesión inválida", null));
        };
        return new DelegatingOAuth2TokenValidator<>(JwtValidators.createDefaultWithIssuer(issuer),claims);
    }
    @Bean SecurityFilterChain security(HttpSecurity http) throws Exception {
        return http.csrf(csrf -> csrf.disable())
                .cors(cors -> {})
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(authorize -> authorize
                    .requestMatchers(HttpMethod.OPTIONS,"/**").permitAll()
                    .requestMatchers("/health").permitAll()
                    .requestMatchers(HttpMethod.POST,"/api/auth/login","/api/auth/register","/api/auth/refresh").permitAll()
                    .anyRequest().authenticated())
                .oauth2ResourceServer(resource -> resource.jwt(jwt -> {}))
                .build();
    }
    @Bean CorsConfigurationSource corsConfigurationSource(@Value("${ridemove.cors-origins}") String origins) {
        var cors = new CorsConfiguration();
        cors.setAllowedOrigins(Arrays.stream(origins.split(",")).map(String::trim).filter(s -> !s.isEmpty()).toList());
        cors.setAllowedMethods(List.of("GET","POST","PUT","OPTIONS"));
        cors.setAllowedHeaders(List.of("Authorization","Content-Type"));
        var source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**",cors);
        return source;
    }
}
