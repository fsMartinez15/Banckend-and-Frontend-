package co.ridemove.domain;

public class BusinessRule extends RuntimeException {
    public BusinessRule(String message) { super(message); }
    public static void require(boolean valid, String message) {
        if (!valid) throw new BusinessRule(message);
    }
    public static String text(String value, int min, int max, String field) {
        var text = value == null ? "" : value.trim();
        require(text.length() >= min && text.length() <= max, field + ": longitud inválida");
        return text;
    }
}
