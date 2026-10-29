import 'fare.dart';

typedef JsonRow = Map<String, dynamic>;

class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);
  @override
  String toString() => message;
}

class Coordinates {
  final double latitude, longitude;
  const Coordinates(this.latitude, this.longitude);
  @override
  bool operator ==(Object other) =>
      other is Coordinates &&
      other.latitude == latitude &&
      other.longitude == longitude;
  @override
  int get hashCode => Object.hash(latitude, longitude);
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
  Future<bool> signUp(
    String email,
    String password,
    String name,
    String role, {
    String document = '',
  });
  Future<void> signOut();
  Future<JsonRow> profile();
  Future<List<JsonRow>> trips();
  Future<List<JsonRow>> users();
  Future<List<JsonRow>> vehicles();
  Future<List<JsonRow>> locations();

  /// Tarifa vigente (banderazo, km, minuto y mínima).
  Future<Tariff> tariff();

  /// Conductores conectados cerca de un punto (posición aproximada).
  Future<List<Coordinates>> nearbyDrivers(Coordinates around);

  /// Pagos visibles para el usuario (Wompi).
  Future<List<JsonRow>> payments();

  /// Enlace firmado del checkout de Wompi para un viaje finalizado.
  Future<String> checkoutUrl(String tripId);
  Future<void> command(String name, JsonRow params);
}

const activeStatuses = {'pending', 'accepted', 'arrived', 'in_progress'};
const assignedStatuses = {'accepted', 'arrived', 'in_progress'};

const statusLabels = {
  'pending': 'Buscando conductor',
  'accepted': 'Conductor en camino',
  'arrived': 'Tu conductor llegó',
  'in_progress': 'En viaje',
  'completed': 'Finalizado',
  'cancelled': 'Cancelado',
};
const roleLabels = {
  'passenger': 'Pasajero',
  'driver': 'Conductor',
  'admin': 'Administrador',
};
const paymentLabels = {'cash': 'Efectivo', 'wompi': 'Tarjeta, Nequi o PSE'};

/// Máquina de estados tipo Uber. `pending` como destino = el conductor libera el viaje.
bool canTransition(String from, String to) => switch ('$from:$to') {
  'pending:accepted' ||
  'pending:cancelled' ||
  'accepted:cancelled' ||
  'arrived:cancelled' ||
  'accepted:arrived' ||
  'accepted:in_progress' ||
  'arrived:in_progress' ||
  'in_progress:completed' ||
  'accepted:pending' ||
  'arrived:pending' => true,
  _ => false,
};

/// Lectura tipada de una fila de viaje.
extension TripRow on JsonRow {
  String get tripStatus => '${this['status']}';
  bool get isActiveTrip => activeStatuses.contains(tripStatus);
  Coordinates? _point(String lat, String lng) {
    final a = this[lat], b = this[lng];
    return a is num && b is num
        ? Coordinates(a.toDouble(), b.toDouble())
        : null;
  }

  Coordinates? get pickup => _point('origin_lat', 'origin_lng');
  Coordinates? get dropoff => _point('destination_lat', 'destination_lng');
  int? get fareCents => (this['fare_cents'] as num?)?.toInt();
  int? get distanceMeters => (this['distance_m'] as num?)?.toInt();
  int? get durationSeconds => (this['duration_s'] as num?)?.toInt();
  String get paymentMethod => '${this['payment_method'] ?? 'cash'}';
}

/// Viaje finalizado más reciente (por fecha de finalización).
JsonRow? latestCompleted(Iterable<JsonRow> trips) {
  JsonRow? best;
  DateTime? bestAt;
  for (final t in trips.where((t) => t.tripStatus == 'completed')) {
    final at = DateTime.tryParse('${t['completed_at'] ?? ''}');
    if (best == null ||
        (at != null && (bestAt == null || at.isAfter(bestAt)))) {
      best = t;
      bestAt = at;
    }
  }
  return best;
}
