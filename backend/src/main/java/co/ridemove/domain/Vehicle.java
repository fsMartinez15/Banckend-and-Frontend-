package co.ridemove.domain;

public record Vehicle(String driver_id, String plate, String brand, String model, String color, String license) {
    public Vehicle validated() {
        return new Vehicle(driver_id, BusinessRule.text(plate,3,10,"Placa").toUpperCase(java.util.Locale.ROOT),
                BusinessRule.text(brand,1,40,"Marca"), BusinessRule.text(model,1,20,"Modelo"),
                BusinessRule.text(color,1,30,"Color"), BusinessRule.text(license,1,40,"Licencia"));
    }
}
