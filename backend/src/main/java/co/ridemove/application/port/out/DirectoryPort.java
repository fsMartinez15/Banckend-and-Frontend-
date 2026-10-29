package co.ridemove.application.port.out;

/** Consultas de identidad que solo el backend puede hacer (clave secreta del servidor). */
public interface DirectoryPort {
    /** Correo de la cuenta activa con ese documento, o null. */
    String emailForDocument(String documentNumber);
    boolean documentRegistered(String documentNumber);
}
