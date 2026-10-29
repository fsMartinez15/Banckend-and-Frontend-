package co.ridemove;
import co.ridemove.bootstrap.RideMoveServer;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(classes=RideMoveServer.class,properties={"ridemove.supabase-url=http://localhost:1","ridemove.supabase-key=test","ridemove.cors-origins=http://127.0.0.1:4200"})
@AutoConfigureMockMvc
class HttpSecurityTest {
    @Autowired MockMvc mvc;
    @Test void healthIsPublic() throws Exception { mvc.perform(get("/health")).andExpect(status().isOk()); }
    @Test void businessApiRequiresSession() throws Exception { mvc.perform(get("/api/trips")).andExpect(status().isUnauthorized()); }
    @Test void arbitraryRoleHeaderDoesNotAuthorize() throws Exception { mvc.perform(get("/api/profiles").header("role","admin")).andExpect(status().isUnauthorized()); }
    @Test void configuredWebOriginCanPreflightLogin() throws Exception {
        mvc.perform(options("/api/auth/login").header("Origin","http://127.0.0.1:4200")
            .header("Access-Control-Request-Method","POST").header("Access-Control-Request-Headers","Content-Type"))
            .andExpect(status().isOk()).andExpect(header().string("Access-Control-Allow-Origin","http://127.0.0.1:4200"));
    }
    @Test void wompiEventsArePublicButMustBeSigned() throws Exception {
        mvc.perform(post("/api/payments/wompi/events").contentType("application/json")
            .content("{\"event\":\"transaction.updated\",\"data\":{\"transaction\":{\"id\":\"1\",\"status\":\"APPROVED\"}},\"signature\":{\"properties\":[\"transaction.id\"],\"checksum\":\"x\"},\"timestamp\":1}"))
            .andExpect(status().isBadRequest());
    }
    @Test void checkoutRequiresSession() throws Exception {
        mvc.perform(post("/api/payments/checkout").contentType("application/json").content("{\"tripId\":\"x\"}")).andExpect(status().isUnauthorized());
    }
    @Test void unconfiguredOriginIsRejected() throws Exception {
        mvc.perform(options("/api/auth/login").header("Origin","https://untrusted.example")
            .header("Access-Control-Request-Method","POST")).andExpect(status().isForbidden());
    }
}
