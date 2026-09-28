typedef JsonRow = Map<String, dynamic>;

class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);
}

class Coordinates {
  final double latitude, longitude;
  const Coordinates(this.latitude, this.longitude);
}

abstract interface class LocationDevice {
  Future<void> requestPermission();
  Future<Coordinates> current();
  Stream<Coordinates> watch();
}

abstract class RideRepository {
  bool get demo;
  bool get signedIn;
  Future<void> signIn(String email, String password);
  Future<bool> signUp(String email, String password, String name, String role);
  Future<void> signOut();
  Future<JsonRow> profile();
  Future<List<JsonRow>> trips();
  Future<List<JsonRow>> users();
  Future<List<JsonRow>> vehicles();
  Future<List<JsonRow>> locations();
  Future<void> command(String name, JsonRow params);
}

const statusLabels = {
  'pending': 'Buscando conductor',
  'accepted': 'Conductor asignado',
  'in_progress': 'En camino',
  'completed': 'Finalizado',
  'cancelled': 'Cancelado',
};
const roleLabels = {
  'passenger': 'Pasajero',
  'driver': 'Conductor',
  'admin': 'Administrador',
};

bool canTransition(String from, String to) =>
    (from == 'pending' && (to == 'accepted' || to == 'cancelled')) ||
    (from == 'accepted' && to == 'in_progress') ||
    (from == 'in_progress' && to == 'completed');
