package co.ridemove;
import co.ridemove.application.PaymentService;
import co.ridemove.application.port.out.PaymentGatewayPort;
import co.ridemove.application.port.out.PaymentStorePort;
import co.ridemove.domain.*;
import org.junit.jupiter.api.Test;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class PaymentServiceTest {
    final PaymentStorePort store=mock(PaymentStorePort.class);
    final PaymentGatewayPort gateway=mock(PaymentGatewayPort.class);
    final PaymentSettings settings=new PaymentSettings("pub_test_x","integrity_x","events_x","https://checkout.wompi.co/p/","http://127.0.0.1:4200/pago/resultado",800000);
    final PaymentService app=new PaymentService(store,gateway,settings);
    final Profile client=new Profile("p","Laura Gómez","3105550000","passenger",true,false,"CC","1069700001");
    Trip trip(String status) { return new Trip("11111111-2222-3333-4444-555555555555","p","d","Centro","Terminal",status,"",null,null,null); }
    static Map<String,String> query(String url) {
        var map=new HashMap<String,String>();
        for (var part:url.substring(url.indexOf('?')+1).split("&")) { var kv=part.split("=",2); map.put(URLDecoder.decode(kv[0],StandardCharsets.UTF_8),URLDecoder.decode(kv[1],StandardCharsets.UTF_8)); }
        return map;
    }
    @Test void checkoutIsSignedAndCarriesCedula() {
        var link=app.checkout(client,"laura@example.com",trip("completed"));
        var q=query(link.url());
        assertTrue(link.url().startsWith("https://checkout.wompi.co/p/?"));
        assertEquals("800000",q.get("amount-in-cents"));
        assertEquals(PaymentSignature.sha256(link.reference()+"800000COPintegrity_x"),q.get("signature:integrity"));
        assertEquals("1069700001",q.get("customer-data:legal-id"));
        assertEquals("CC",q.get("customer-data:legal-id-type"));
        assertFalse(link.url().contains("integrity_x"));
        verify(store).create(argThat(p -> p.status().equals("PENDING") && p.amount_in_cents()==800000));
    }
    @Test void onlyCompletedUnpaidOwnTrips() {
        assertThrows(BusinessRule.class,()->app.checkout(client,"",trip("in_progress")));
        assertThrows(BusinessRule.class,()->app.checkout(new Profile("x","Otro","","passenger",true,false),"",trip("completed")));
        when(store.approvedForTrip(any())).thenReturn(true);
        assertThrows(BusinessRule.class,()->app.checkout(client,"",trip("completed")));
    }
    @Test void validEventApprovesPayment() {
        var pending=new Payment("1","t","p","RM-REF-1",800000,"COP","PENDING",null,null,null,null);
        when(store.byReference("RM-REF-1")).thenReturn(Optional.of(pending));
        var tx=new GatewayTransaction("123-1","RM-REF-1","APPROVED",800000,"COP","CARD");
        var values=List.of("123-1","APPROVED","800000");
        var checksum=PaymentSignature.eventChecksum(values,1530291411L,"events_x");
        assertTrue(app.handleEvent(new PaymentEvent("transaction.updated",values,1530291411L,checksum,tx)));
        verify(store).update("RM-REF-1","APPROVED","123-1","CARD");
    }
    @Test void forgedEventIsIgnored() {
        var tx=new GatewayTransaction("123-1","RM-REF-1","APPROVED",800000,"COP","CARD");
        assertFalse(app.handleEvent(new PaymentEvent("transaction.updated",List.of("123-1","APPROVED","800000"),1L,"abc",tx)));
        verifyNoInteractions(store);
    }
    @Test void amountMismatchNeverApproves() {
        when(store.byReference("R")).thenReturn(Optional.of(new Payment("1","t","p","R",800000,"COP","PENDING",null,null,null,null)));
        when(gateway.transaction("tx-12")).thenReturn(new GatewayTransaction("tx-12","R","APPROVED",100,"COP","NEQUI"));
        assertEquals("ERROR",app.sync("tx-12").status());
        verify(store).update("R","ERROR","tx-12","NEQUI");
    }
}
