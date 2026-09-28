package co.ridemove.domain;

/** Supabase issues access JWTs. Tokens must never be written to logs. */
public record AuthSession(String access_token, String refresh_token, Long expires_in,
                          String token_type, AuthUser user) {
    public record AuthUser(String id, String email) {}
}
