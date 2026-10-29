package co.ridemove;
import co.ridemove.application.AuthService;
import co.ridemove.application.port.out.DirectoryPort;
import co.ridemove.application.port.out.IdentityPort;
import co.ridemove.domain.BusinessRule;
import co.ridemove.domain.SignUp;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class AuthServiceTest {
    private final IdentityPort identity=mock(IdentityPort.class);
    private final DirectoryPort directory=mock(DirectoryPort.class);
    private final AuthService auth=new AuthService(identity,directory);
    @Test void loginNormalizesEmailAndPreservesPassword() {
        auth.login(" USER@Example.com "," pass word ");
        verify(identity).login("user@example.com"," pass word ");
        verifyNoInteractions(directory);
    }
    @Test void loginWithCedulaResolvesEmail() {
        when(directory.emailForDocument("1069700001")).thenReturn("cliente@ridemove.co");
        auth.login("1.069.700.001","Password123");
        verify(identity).login("cliente@ridemove.co","Password123");
    }
    @Test void unknownCedulaIsRejected() {
        assertThrows(BusinessRule.class,()->auth.login("123456789","Password123"));
        verifyNoInteractions(identity);
    }
    @Test void cannotRegisterAdministrator() {
        assertThrows(BusinessRule.class,()->auth.register("a@example.com","Password123","User","admin","CC","12345678",""));
        verifyNoInteractions(identity);
    }
    @Test void clientMustRegisterCedula() {
        assertThrows(BusinessRule.class,()->auth.register("a@example.com","Password123","User","passenger","CC","",""));
        assertThrows(BusinessRule.class,()->auth.register("a@example.com","Password123","User","passenger","CC","12AB",""));
        verifyNoInteractions(identity);
    }
    @Test void duplicatedCedulaIsRejected() {
        when(directory.documentRegistered("12345678")).thenReturn(true);
        assertThrows(BusinessRule.class,()->auth.register("a@example.com","Password123","User","passenger","CC","12345678",""));
        verify(identity,never()).register(any());
    }
    @Test void rejectsInvalidEmailAndShortPassword() {
        assertThrows(BusinessRule.class,()->auth.register("invalid","12345678","User","passenger","CC","12345678",""));
        assertThrows(BusinessRule.class,()->auth.register("a@example.com","123","User","passenger","CC","12345678",""));
        verifyNoInteractions(identity);
    }
    @Test void registrationUsesTypedIdentityPort() {
        auth.register("a@example.com","Password123"," User ","passenger","cc","1.069.700.001","310 555 0000");
        verify(identity).register(new SignUp("a@example.com","Password123","User","passenger","CC","1069700001","3105550000"));
    }
    @Test void driverDocumentIsOptional() {
        auth.register("d@example.com","Password123","Driver","driver",null,null,null);
        verify(identity).register(new SignUp("d@example.com","Password123","Driver","driver","CC",null,""));
    }
}
