package co.ridemove.domain;

import java.util.Locale;
import java.util.Set;
import static co.ridemove.domain.BusinessRule.*;

/** Datos de registro ya validados. Los clientes (pasajeros) deben registrar su documento. */
public record SignUp(String email, String password, String name, String role,
                     String documentType, String documentNumber, String phone) {
    public static final Set<String> DOCUMENT_TYPES = Set.of("CC", "CE", "PP", "TI");

    public static String normalizeDocument(String value) {
        return value == null ? "" : value.replaceAll("[^A-Za-z0-9]", "").toUpperCase(Locale.ROOT);
    }
    public static boolean looksLikeDocument(String value) {
        return normalizeDocument(value).matches("^[A-Z0-9]{5,16}$") && !value.contains("@");
    }
    public static String validDocument(String type, String number) {
        var doc = normalizeDocument(number);
        if ("CC".equals(type) || "TI".equals(type)) require(doc.matches("^\\d{5,10}$"), "La cédula debe tener entre 5 y 10 dígitos");
        else require(doc.matches("^[A-Z0-9]{5,16}$"), "Número de documento inválido");
        return doc;
    }
    public static SignUp of(String email, String password, String name, String role,
                            String documentType, String documentNumber, String phone) {
        require("passenger".equals(role) || "driver".equals(role), "Rol de registro inválido");
        var type = documentType == null || documentType.isBlank() ? "CC" : documentType.trim().toUpperCase(Locale.ROOT);
        require(DOCUMENT_TYPES.contains(type), "Tipo de documento inválido");
        var hasDocument = documentNumber != null && !documentNumber.isBlank();
        require(hasDocument || !"passenger".equals(role), "Para registrarte como cliente debes ingresar tu número de cédula");
        var doc = hasDocument ? validDocument(type, documentNumber) : null;
        var cell = phone == null ? "" : phone.replaceAll("[^0-9+]", "");
        require(cell.length() <= 15, "Teléfono inválido");
        return new SignUp(email, password, text(name, 2, 80, "Nombre"), role, type, doc, cell);
    }
}
