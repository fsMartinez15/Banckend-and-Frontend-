package co.ridemove;
import co.ridemove.adapter.out.SupabaseAdapter;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClient;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.http.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.*;

class SupabaseAdapterTest {
    @Test void transitionUsesAuthenticatedAtomicRpc() {
        var builder=RestClient.builder().baseUrl("https://example.supabase.co").defaultHeader("Authorization","Bearer user-token");
        var server=MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://example.supabase.co/rest/v1/rpc/transition_trip"))
                .andExpect(method(HttpMethod.POST)).andExpect(header("Authorization","Bearer user-token"))
                .andExpect(content().json("{\"p_id\":\"t\",\"p_status\":\"accepted\"}"))
                .andRespond(withSuccess());
        new SupabaseAdapter(builder.build(),"d").transitionTrip("t","accepted"); server.verify();
    }
}
