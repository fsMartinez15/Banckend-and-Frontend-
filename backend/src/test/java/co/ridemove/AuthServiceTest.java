package co.ridemove;
import co.ridemove.application.AuthService;
import co.ridemove.application.port.out.IdentityPort;
import co.ridemove.domain.BusinessRule;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AuthServiceTest {
    private final IdentityPort identity=mock(IdentityPort.class);
    private final AuthService auth=new AuthService(identity);
    @Test void loginNormalizesEmailAndPreservesPassword() {
        auth.login(" USER@Example.com "," pass word ");
        verify(identity).login("user@example.com"," pass word ");
    }
    @Test void cannotRegisterAdministrator() {
        assertThrows(BusinessRule.class,()->auth.register("a@example.com","Password123","User","admin"));
        verifyNoInteractions(identity);
    }
    @Test void rejectsInvalidEmailAndShortPassword() {
        assertThrows(BusinessRule.class,()->auth.register("invalid","12345678","User","passenger"));
        assertThrows(BusinessRule.class,()->auth.register("a@example.com","123","User","passenger"));
        verifyNoInteractions(identity);
    }
    @Test void registrationUsesTypedIdentityPort() {
        auth.register("a@example.com","Password123"," User ","driver");
        verify(identity).register("a@example.com","Password123","User","driver");
    }
}
