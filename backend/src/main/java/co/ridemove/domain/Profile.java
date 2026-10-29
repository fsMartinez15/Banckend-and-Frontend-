package co.ridemove.domain;

public record Profile(String id, String name, String phone, String role, boolean active, boolean available,
                      String document_type, String document_number) {
    public Profile(String id, String name, String phone, String role, boolean active, boolean available) {
        this(id, name, phone, role, active, available, "CC", null);
    }
    public void requireActive() { BusinessRule.require(active, "Cuenta suspendida"); }
    public void requireRole(String required) {
        requireActive();
        BusinessRule.require(required.equals(role), "Esta operación requiere el rol " + required);
    }
}
