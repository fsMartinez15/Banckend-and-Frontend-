package co.ridemove.adapter.in;

import co.ridemove.domain.BusinessRule;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.*;
import org.springframework.web.client.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import java.util.Map;

@RestControllerAdvice
public class ApiErrors {
    @ExceptionHandler(BusinessRule.class)
    ResponseEntity<?> business(BusinessRule e) { return ResponseEntity.status(409).body(Map.of("message",e.getMessage())); }
    @ExceptionHandler({HttpMessageNotReadableException.class,IllegalArgumentException.class})
    ResponseEntity<?> invalid(Exception e) { return ResponseEntity.badRequest().body(Map.of("message","Datos inválidos")); }
    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<?> status(ResponseStatusException e) { return ResponseEntity.status(e.getStatusCode()).body(Map.of("message","Sesión no válida")); }
    @ExceptionHandler(RestClientResponseException.class)
    ResponseEntity<?> upstream(RestClientResponseException e) {
        int status=e.getStatusCode().value();
        return ResponseEntity.status(status==401 || status==403 ? status : 409)
                .body(Map.of("message",status==401 ? "Tu sesión venció. Inicia sesión otra vez." : "La operación no está permitida o los datos cambiaron. Actualiza e inténtalo de nuevo."));
    }
    @ExceptionHandler(RestClientException.class)
    ResponseEntity<?> unavailable(RestClientException e) { return ResponseEntity.status(503).body(Map.of("message","Servicio temporalmente no disponible")); }
}
