import 'dart:math' as math;
import '../domain/fare.dart';
import '../domain/ride_repository.dart';

/// Repositorio en memoria para recorrer la app sin backend.
/// Con [autopilot] un conductor simulado acepta, llega, inicia y termina los viajes
/// del pasajero, y aparecen solicitudes nuevas para el conductor.
class DemoRepository implements RideRepository {
  final bool autopilot;
  final DateTime Function() now;
  DemoRepository({this.autopilot = false, DateTime Function()? clock})
    : now = clock ?? DateTime.now;

  static const universidad = Coordinates(4.33598, -74.37123);
  static const plazaMayor = Coordinates(4.34391, -74.36196);
  static const terminal = Coordinates(4.34262, -74.35851);
  static const manila = Coordinates(4.33930, -74.36420);

  String? current;
  int sequence = 3;
  final tariffValue = Tariff.standard;
  final List<JsonRow> people = [
    {
      'id': 'passenger',
      'name': 'Laura Díaz',
      'role': 'passenger',
      'phone': '300 123 4567',
      'active': true,
      'available': false,
      'document_type': 'CC',
      'document_number': '1069700001',
    },
    {
      'id': 'passenger2',
      'name': 'Carlos Rojas',
      'role': 'passenger',
      'phone': '301 765 4321',
      'active': true,
      'available': false,
    },
    {
      'id': 'driver',
      'name': 'Fabián Martínez',
      'role': 'driver',
      'phone': '310 234 5678',
      'active': true,
      'available': false,
      'rating_avg': 4.9,
      'rating_count': 128,
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
  late final List<JsonRow> rides = [
    _ride(
      '1',
      'passenger2',
      'Universidad de Cundinamarca',
      universidad,
      'Plaza Mayor',
      plazaMayor,
      now().subtract(const Duration(minutes: 1)),
    ),
    {
      ..._ride(
        '2',
        'passenger',
        'Terminal de transporte',
        terminal,
        'Universidad de Cundinamarca',
        universidad,
        now().subtract(const Duration(days: 1, hours: 2)),
      ),
      'status': 'completed',
      'driver_id': 'driver',
      'completed_at': now()
          .subtract(const Duration(days: 1, hours: 1, minutes: 45))
          .toIso8601String(),
      'rating': 5,
      'comment': 'Muy amable',
    },
  ];
  final List<JsonRow> cars = [
    {
      'driver_id': 'driver',
      'plate': 'FUS 204',
      'brand': 'Chevrolet Spark',
      'model': '2022',
      'color': 'Gris',
      'license': 'DEMO-001',
    },
  ];
  final List<JsonRow> positions = [];
  final List<JsonRow> paid = [];
  final Set<String> rejected = {};
  DateTime? _lastSpawn;

  JsonRow _ride(
    String id,
    String passenger,
    String origin,
    Coordinates from,
    String destination,
    Coordinates to,
    DateTime at, {
    String payment = 'cash',
    int? meters,
    int? seconds,
  }) {
    final distance = meters ?? (haversine(from, to) * 1.3).round();
    final duration = seconds ?? (distance / (24000 / 3600)).round();
    return {
      'id': id,
      'passenger_id': passenger,
      'driver_id': null,
      'origin': origin,
      'destination': destination,
      'origin_lat': from.latitude,
      'origin_lng': from.longitude,
      'destination_lat': to.latitude,
      'destination_lng': to.longitude,
      'distance_m': distance,
      'duration_s': duration,
      'fare_cents': tariffValue.estimate(distance, duration),
      'payment_method': payment,
      'status': 'pending',
      'created_at': at.toIso8601String(),
      'rating': null,
      'comment': null,
    };
  }

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
    String role, {
    String document = '',
  }) async {
    current = role;
    return true;
  }

  @override
  Future<void> signOut() async {
    current = null;
  }

  JsonRow get _me => people.firstWhere((p) => p['id'] == current);
  static JsonRow _public(JsonRow row) =>
      Map<String, dynamic>.of(row)..removeWhere((k, _) => k.startsWith('_'));

  @override
  Future<JsonRow> profile() async {
    _tick();
    return Map.of(_me);
  }

  @override
  Future<List<JsonRow>> trips() async {
    _tick();
    return rides
        .where(
          (r) =>
              current == 'admin' ||
              (_me['role'] == 'passenger' && r['passenger_id'] == current) ||
              (_me['role'] == 'driver' &&
                  (r['driver_id'] == current ||
                      (r['status'] == 'pending' &&
                          r['_auto'] != true &&
                          !rejected.contains(r['id'])))),
        )
        .map(_public)
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<List<JsonRow>> users() async => people.map(_public).toList();
  @override
  Future<List<JsonRow>> vehicles() async => cars.map(_public).toList();
  @override
  Future<List<JsonRow>> locations() async {
    _tick();
    return positions.map(_public).toList();
  }

  @override
  Future<Tariff> tariff() async => tariffValue;

  @override
  Future<List<Coordinates>> nearbyDrivers(Coordinates around) async {
    final t = now().millisecondsSinceEpoch / 1000;
    return List.generate(5, (i) {
      final angle = (i * 72 + t * 3) * math.pi / 180;
      final meters = 350.0 + i * 220;
      return Coordinates(
        around.latitude + meters / 111320 * math.cos(angle),
        around.longitude + meters / 111320 * math.sin(angle),
      );
    });
  }

  @override
  Future<List<JsonRow>> payments() async => paid.map(_public).toList();

  @override
  Future<String> checkoutUrl(String tripId) async {
    final ride = rides.firstWhere((r) => r['id'] == tripId);
    paid.add({
      'trip_id': tripId,
      'status': 'APPROVED',
      'amount_in_cents': ride['fare_cents'],
      'reference': 'DEMO-$tripId',
    });
    return 'demo:aprobado';
  }

  void _place(String driver, Coordinates p) {
    positions.removeWhere((v) => v['driver_id'] == driver);
    positions.add({
      'driver_id': driver,
      'latitude': p.latitude,
      'longitude': p.longitude,
      'updated_at': now().toIso8601String(),
    });
  }

  static Coordinates _lerp(Coordinates a, Coordinates b, double t) =>
      Coordinates(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  /// Avanza el viaje simulado según el tiempo transcurrido.
  void _tick() {
    if (!autopilot) return;
    final time = now();
    for (final r in rides.where((r) => r['_auto'] == true && r.isActiveTrip)) {
      final since = time.difference(r['_stage_at'] as DateTime);
      final pickup = r.pickup!, dropoff = r.dropoff!;
      switch (r['status']) {
        case 'pending' when since.inSeconds >= 6:
          final start = Coordinates(
            pickup.latitude + 0.0085,
            pickup.longitude + 0.0065,
          );
          r
            ..['status'] = 'accepted'
            ..['driver_id'] = 'driver'
            ..['accepted_at'] = time.toIso8601String()
            ..['_from'] = start
            ..['_stage_at'] = time;
          _place('driver', start);
        case 'accepted':
          final progress = math.min(1.0, since.inMilliseconds / 24000);
          _place('driver', _lerp(r['_from'] as Coordinates, pickup, progress));
          if (progress >= 1) {
            r
              ..['status'] = 'arrived'
              ..['arrived_at'] = time.toIso8601String()
              ..['_stage_at'] = time;
          }
        case 'arrived' when since.inSeconds >= 8:
          r
            ..['status'] = 'in_progress'
            ..['started_at'] = time.toIso8601String()
            ..['_stage_at'] = time;
        case 'in_progress':
          final progress = math.min(1.0, since.inMilliseconds / 30000);
          _place('driver', _lerp(pickup, dropoff, progress));
          if (progress >= 1) {
            r
              ..['status'] = 'completed'
              ..['completed_at'] = time.toIso8601String();
            positions.removeWhere((v) => v['driver_id'] == 'driver');
          }
      }
    }
    // El conductor de la demo recibe solicitudes nuevas de pasajeros simulados.
    if (current == 'driver' &&
        _me['available'] == true &&
        !rides.any(
          (r) =>
              r['status'] == 'pending' &&
              r['_auto'] != true &&
              !rejected.contains(r['id']),
        ) &&
        !rides.any(
          (r) =>
              r['driver_id'] == 'driver' &&
              assignedStatuses.contains(r['status']),
        ) &&
        (_lastSpawn == null || time.difference(_lastSpawn!).inSeconds >= 10)) {
      _lastSpawn = time;
      final places = [
        ('Centro comercial Manila', manila),
        ('Terminal de transporte', terminal),
        ('Plaza Mayor', plazaMayor),
        ('Universidad de Cundinamarca', universidad),
      ];
      final a = places[sequence % 4], b = places[(sequence + 2) % 4];
      rides.add(
        _ride('${sequence++}', 'passenger2', a.$1, a.$2, b.$1, b.$2, time),
      );
    }
  }

  @override
  Future<void> command(String name, JsonRow p) async {
    final me = _me;
    if (me['active'] != true) {
      throw const AppFailure('Cuenta suspendida');
    }
    switch (name) {
      case 'save_profile':
        me['name'] = p['p_name'];
        me['phone'] = p['p_phone'];
      case 'set_availability':
        if (me['role'] != 'driver') {
          throw const AppFailure(
            'Solo los conductores pueden cambiar disponibilidad',
          );
        }
        if (p['p_available'] == true &&
            !cars.any((v) => v['driver_id'] == current)) {
          throw const AppFailure('Registra tu vehículo antes de conectarte');
        }
        me['available'] = p['p_available'];
        if (p['p_available'] != true) {
          positions.removeWhere((v) => v['driver_id'] == current);
        }
      case 'create_trip' || 'request_trip':
        if (me['role'] != 'passenger') {
          throw const AppFailure('Solo los pasajeros pueden solicitar viajes');
        }
        if (rides.any((r) => r['passenger_id'] == current && r.isActiveTrip)) {
          throw const AppFailure('Ya tienes un viaje activo');
        }
        final origin = '${p['p_origin'] ?? ''}'.trim(),
            destination = '${p['p_destination'] ?? ''}'.trim();
        if (origin.length < 3 || destination.length < 3) {
          throw const AppFailure('Escribe el origen y el destino.');
        }
        if (origin.toLowerCase() == destination.toLowerCase()) {
          throw const AppFailure('Elige un destino distinto al origen.');
        }
        final from = p['p_origin_lat'] is num
            ? Coordinates(
                (p['p_origin_lat'] as num).toDouble(),
                (p['p_origin_lng'] as num).toDouble(),
              )
            : universidad;
        final to = p['p_destination_lat'] is num
            ? Coordinates(
                (p['p_destination_lat'] as num).toDouble(),
                (p['p_destination_lng'] as num).toDouble(),
              )
            : plazaMayor;
        final straight = haversine(from, to);
        final meters = math.max(
          (p['p_distance_m'] as num?)?.toInt() ?? 0,
          straight.ceil(),
        );
        rides.add({
          ..._ride(
            '${sequence++}',
            current!,
            origin,
            from,
            destination,
            to,
            now(),
            payment: '${p['p_payment_method'] ?? 'cash'}',
            meters: meters,
            seconds: (p['p_duration_s'] as num?)?.toInt(),
          ),
          if (autopilot) '_auto': true,
          '_stage_at': now(),
        });
      case 'reject_trip':
        if (me['role'] != 'driver') {
          throw const AppFailure(
            'Solo los conductores pueden rechazar solicitudes',
          );
        }
        rejected.add('${p['p_id']}');
      case 'transition_trip':
        final ride = rides.firstWhere((r) => r['id'] == p['p_id']);
        final to = '${p['p_status']}';
        if (!canTransition(ride.tripStatus, to)) {
          throw const AppFailure('El estado del viaje cambió');
        }
        final stamp = now().toIso8601String();
        if (to == 'accepted') {
          if (me['role'] != 'driver' ||
              me['available'] != true ||
              rides.any(
                (r) =>
                    r['driver_id'] == current &&
                    assignedStatuses.contains(r['status']),
              )) {
            throw const AppFailure('Conéctate para aceptar viajes');
          }
          ride
            ..['driver_id'] = current
            ..['accepted_at'] = stamp;
        } else if (to == 'cancelled') {
          if (me['role'] != 'passenger' || ride['passenger_id'] != current) {
            throw const AppFailure(
              'Solo el pasajero puede cancelar esta solicitud',
            );
          }
          ride
            ..['cancelled_at'] = stamp
            ..['cancelled_by'] = 'passenger';
        } else if (me['role'] != 'driver' || ride['driver_id'] != current) {
          throw const AppFailure(
            'Solo el conductor asignado puede actualizar el viaje',
          );
        } else if (to == 'pending') {
          rejected.add('${ride['id']}');
          ride
            ..['driver_id'] = null
            ..['accepted_at'] = null
            ..['arrived_at'] = null;
        } else {
          ride[switch (to) {
                'arrived' => 'arrived_at',
                'in_progress' => 'started_at',
                _ => 'completed_at',
              }] =
              stamp;
        }
        ride
          ..['status'] = to
          ..['_stage_at'] = now();
      case 'rate_trip':
        final ride = rides.firstWhere((r) => r['id'] == p['p_id']);
        if (me['role'] != 'passenger' ||
            ride['passenger_id'] != current ||
            ride['status'] != 'completed' ||
            ride['rating'] != null) {
          throw const AppFailure('Este viaje no se puede calificar');
        }
        ride['rating'] = p['p_rating'];
        ride['comment'] = p['p_comment'];
        final driver = people.where((u) => u['id'] == ride['driver_id']);
        for (final d in driver) {
          final count = ((d['rating_count'] as num?) ?? 0).toInt();
          final avg = ((d['rating_avg'] as num?) ?? 0).toDouble();
          d['rating_count'] = count + 1;
          d['rating_avg'] =
              ((avg * count + (p['p_rating'] as num)) / (count + 1) * 100)
                  .round() /
              100;
        }
      case 'save_vehicle':
        if (me['role'] != 'driver' && me['role'] != 'admin') {
          throw const AppFailure(
            'Solo los conductores pueden registrar vehículos',
          );
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
          throw const AppFailure(
            'Solo los conductores pueden compartir ubicación',
          );
        }
        _place(
          current!,
          Coordinates(
            (p['p_latitude'] as num).toDouble(),
            (p['p_longitude'] as num).toDouble(),
          ),
        );
      case 'admin_set_active':
        if (me['role'] != 'admin') {
          throw const AppFailure('Solo administración puede cambiar accesos');
        }
        people.firstWhere((u) => u['id'] == p['p_id'])['active'] =
            p['p_active'];
      default:
        throw UnimplementedError(name);
    }
  }
}
