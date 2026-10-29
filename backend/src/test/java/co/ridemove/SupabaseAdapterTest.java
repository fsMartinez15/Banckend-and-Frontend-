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

    @Test void requestTripSendsCoordinatesToRpc() {
        var builder=RestClient.builder().baseUrl("https://example.supabase.co");
        var server=MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://example.supabase.co/rest/v1/rpc/request_trip")).andExpect(method(HttpMethod.POST))
                .andExpect(content().json("{\"p_origin\":\"Centro\",\"p_destination\":\"Terminal\",\"p_origin_lat\":4.33,\"p_destination_lng\":-74.36,\"p_distance_m\":1500,\"p_payment_method\":\"wompi\"}"))
                .andRespond(withSuccess("\"00000000-0000-0000-0000-000000000000\"",MediaType.APPLICATION_JSON));
        new SupabaseAdapter(builder.build(),"p").requestTrip(new co.ridemove.domain.TripDraft("Centro","Terminal",4.33,-74.37,4.34,-74.36,1500,300,"wompi"));
        server.verify();
    }
}
