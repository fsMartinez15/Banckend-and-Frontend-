import '../domain/ride_repository.dart';

class DemoRepository implements RideRepository {
  String? current;
  int sequence = 2;
  final List<JsonRow> people = [
    {
      'id': 'passenger',
      'name': 'Laura Díaz',
      'role': 'passenger',
      'phone': '300 123 4567',
      'active': true,
      'available': false,
    },
    {
      'id': 'driver',
      'name': 'Fabián Martínez',
      'role': 'driver',
      'phone': '310 234 5678',
      'active': true,
      'available': true,
    },
    {
      'id': 'admin',
      'name': 'Administración',
      'role': 'admin',
      'phone': '',
      'active': true,
      'available': false,
    },
  ];
  final List<JsonRow> rides = [
    {
      'id': '1',
      'passenger_id': 'passenger',
      'driver_id': null,
      'origin': 'Universidad de Cundinamarca',
      'destination': 'Parque principal',
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    },
  ];
  final List<JsonRow> cars = [
    {
      'driver_id': 'driver',
      'plate': 'FUS 204',
      'brand': 'Chevrolet',
      'model': '2022',
      'color': 'Gris',
      'license': 'DEMO-001',
    },
  ];
  final List<JsonRow> positions = [];
  final Set<String> rejected = {};
  @override
  bool get demo => true;
  @override
  bool get signedIn => current != null;
  @override
  Future<void> signIn(String email, String password) async {
    current = email;
  }

  @override
  Future<bool> signUp(
    String email,
    String password,
    String name,
    String role,
  ) async {
    current = role;
    return true;
  }

  @override
  Future<void> signOut() async {
    current = null;
  }

  @override
  Future<JsonRow> profile() async =>
      Map.of(people.firstWhere((p) => p['id'] == current));
  @override
  Future<List<JsonRow>> trips() async => rides
      .where(
        (r) =>
            current == 'admin' ||
            (current == 'passenger' && r['passenger_id'] == current) ||
            (current == 'driver' &&
                (r['driver_id'] == current ||
                    (r['status'] == 'pending' && !rejected.contains(r['id'])))),
      )
      .map((r) => Map<String, dynamic>.of(r))
      .toList()
      .reversed
      .toList();
  @override
  Future<List<JsonRow>> users() async =>
      people.map((r) => Map<String, dynamic>.of(r)).toList();
  @override
  Future<List<JsonRow>> vehicles() async =>
      cars.map((r) => Map<String, dynamic>.of(r)).toList();
  @override
  Future<List<JsonRow>> locations() async =>
      positions.map((r) => Map<String, dynamic>.of(r)).toList();
  @override
  Future<void> command(String name, JsonRow p) async {
    final me = people.firstWhere((u) => u['id'] == current);
    if (me['active'] != true) {
      throw StateError('Cuenta suspendida');
    }
    switch (name) {
      case 'save_profile':
        me['name'] = p['p_name'];
        me['phone'] = p['p_phone'];
      case 'set_availability':
        if (me['role'] != 'driver') {
          throw StateError(
            'Solo los conductores pueden cambiar disponibilidad',
          );
        }
        me['available'] = p['p_available'];
      case 'create_trip':
        if (me['role'] != 'passenger') {
          throw StateError('Solo los pasajeros pueden solicitar viajes');
        }
        if (rides.any(
          (r) =>
              r['passenger_id'] == current &&
              !['completed', 'cancelled'].contains(r['status']),
        )) {
          throw StateError('Ya tienes un viaje activo');
        }
        rides.add({
          'id': '${sequence++}',
          'passenger_id': current,
          'driver_id': null,
          'origin': p['p_origin'],
          'destination': p['p_destination'],
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
      case 'reject_trip':
        if (me['role'] != 'driver') {
          throw StateError('Solo los conductores pueden rechazar solicitudes');
        }
        rejected.add(p['p_id']);
      case 'transition_trip':
        final ride = rides.firstWhere((r) => r['id'] == p['p_id']);
        if (!canTransition(ride['status'], p['p_status'])) {
          throw StateError('El estado del viaje cambió');
        }
        if (p['p_status'] == 'accepted') {
          if (me['role'] != 'driver' ||
              me['available'] != true ||
              rides.any(
                (r) =>
                    r['driver_id'] == current &&
                    ['accepted', 'in_progress'].contains(r['status']),
              )) {
            throw StateError('No estás disponible');
          }
          ride['driver_id'] = current;
        } else if (p['p_status'] == 'cancelled') {
          if (me['role'] != 'passenger' || ride['passenger_id'] != current) {
            throw StateError('Solo el pasajero puede cancelar esta solicitud');
          }
        } else if (me['role'] != 'driver' || ride['driver_id'] != current) {
          throw StateError(
            'Solo el conductor asignado puede actualizar el viaje',
          );
        }
        ride['status'] = p['p_status'];
      case 'rate_trip':
        final ride = rides.firstWhere((r) => r['id'] == p['p_id']);
        if (me['role'] != 'passenger' ||
            ride['passenger_id'] != current ||
            ride['status'] != 'completed' ||
            ride['rating'] != null) {
          throw StateError('Este viaje no se puede calificar');
        }
        ride['rating'] = p['p_rating'];
        ride['comment'] = p['p_comment'];
      case 'save_vehicle':
        if (me['role'] != 'driver' && me['role'] != 'admin') {
          throw StateError('Solo los conductores pueden registrar vehículos');
        }
        final owner = me['role'] == 'admin' ? p['p_driver_id'] : current;
        cars.removeWhere((v) => v['driver_id'] == owner);
        cars.add({
          'driver_id': owner,
          'plate': p['p_plate'],
          'brand': p['p_brand'],
          'model': p['p_model'],
          'color': p['p_color'],
          'license': p['p_license'],
        });
      case 'save_location':
        if (me['role'] != 'driver') {
          throw StateError('Solo los conductores pueden compartir ubicación');
        }
        positions.removeWhere((v) => v['driver_id'] == current);
        positions.add({
          'driver_id': current,
          'latitude': p['p_latitude'],
          'longitude': p['p_longitude'],
          'updated_at': DateTime.now().toIso8601String(),
        });
      case 'admin_set_active':
        if (me['role'] != 'admin') {
          throw StateError('Solo administración puede cambiar accesos');
        }
        people.firstWhere((u) => u['id'] == p['p_id'])['active'] =
            p['p_active'];
      default:
        throw UnimplementedError(name);
    }
  }
}
