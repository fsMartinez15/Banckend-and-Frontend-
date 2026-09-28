package co.ridemove.bootstrap;

import co.ridemove.application.port.in.RideUseCases;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.context.annotation.*;
import org.springframework.web.context.annotation.RequestScope;

@Configuration
public class Wiring {
    @Bean @RequestScope(proxyMode=ScopedProxyMode.INTERFACES)
    RideUseCases useCases(HttpServletRequest request) {
        return (RideUseCases) request.getAttribute("rideUseCases");
    }
}
