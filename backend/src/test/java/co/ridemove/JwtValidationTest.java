package co.ridemove;
import co.ridemove.bootstrap.SecurityConfiguration;
import com.nimbusds.jose.*;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.*;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jwt.*;
import org.junit.jupiter.api.*;
import org.springframework.security.oauth2.jwt.*;
import java.time.Instant;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class JwtValidationTest {
    private static RSAKey key;
    private NimbusJwtDecoder decoder;
    private static final String ISSUER="https://identity.example.test/auth/v1";
    @BeforeAll static void keys() throws Exception { key=new RSAKeyGenerator(2048).generate(); }
    @BeforeEach void decoder() throws Exception {
        decoder=NimbusJwtDecoder.withPublicKey(key.toRSAPublicKey()).build();
        decoder.setJwtValidator(SecurityConfiguration.validators(ISSUER,"authenticated"));
    }
    private String token(String issuer,String audience,Instant expiration) throws Exception {
        var jwt=new SignedJWT(new JWSHeader(JWSAlgorithm.RS256),new JWTClaimsSet.Builder()
                .subject("00000000-0000-0000-0000-000000000001").issuer(issuer).audience(audience)
                .issueTime(Date.from(Instant.now().minusSeconds(600))).expirationTime(Date.from(expiration)).build());
        jwt.sign(new RSASSASigner(key));
        return jwt.serialize();
    }
    @Test void verifiesSignedToken() throws Exception {
        assertEquals("00000000-0000-0000-0000-000000000001",decoder.decode(token(ISSUER,"authenticated",Instant.now().plusSeconds(120))).getSubject());
    }
    @Test void rejectsExpiredToken() { assertThrows(JwtException.class,()->decoder.decode(token(ISSUER,"authenticated",Instant.now().minusSeconds(120)))); }
    @Test void rejectsWrongIssuer() { assertThrows(JwtException.class,()->decoder.decode(token("https://evil.example","authenticated",Instant.now().plusSeconds(120)))); }
    @Test void rejectsWrongAudience() { assertThrows(JwtException.class,()->decoder.decode(token(ISSUER,"other",Instant.now().plusSeconds(120)))); }
    @Test void rejectsTamperedSignature() throws Exception {
        var token=token(ISSUER,"authenticated",Instant.now().plusSeconds(120));
        var parts=token.split("\\.");
        parts[2]=(parts[2].startsWith("a") ? "b" : "a")+parts[2].substring(1);
        assertThrows(JwtException.class,()->decoder.decode(String.join(".",parts)));
    }
}
