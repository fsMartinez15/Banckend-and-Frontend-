import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../application/location_tracker.dart';
import '../domain/external_navigation.dart';
import '../domain/fare.dart';
import '../domain/ride_repository.dart';
import '../domain/route_planner.dart';
import 'passenger_screen.dart' show RunAction;
import 'ride_map.dart';
import 'ride_theme.dart';
import 'ride_widgets.dart';

/// Inicio del conductor tipo Uber: conectarse, ver solicitudes cercanas con
/// tarifa, aceptar, navegar a la recogida, "llegué", iniciar, finalizar y cobrar.
class DriverScreen extends StatefulWidget {
  final RideRepository repository;
  final RoutePlanner? planner;
  final LocationTracker? tracker;
  final ExternalNavigation? navigation;
  final JsonRow me;
  final List<JsonRow> trips, users, vehicles, locations;
  final bool busy;
  final RunAction run;
  final void Function(String) notify;
  final VoidCallback onEditVehicle;
  const DriverScreen({
    super.key,
    required this.repository,
    required this.me,
    required this.trips,
    required this.users,
    required this.vehicles,
    required this.locations,
    required this.busy,
    required this.run,
    required this.notify,
    required this.onEditVehicle,
    this.planner,
    this.tracker,
    this.navigation,
  });
  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen>
    with WidgetsBindingObserver {
  RideRepository get repo => widget.repository;
  Coordinates? myPos;
  String? gpsNotice;
  Timer? heartbeat;
  final dismissed = <String>{};
  final legRoutes = <String, List<LatLng>>{};
  int knownRequests = 0;
  final mapKey = GlobalKey<RideMapState>();

  bool get online => widget.me['available'] == true;
  String get myId => '${widget.me['id']}';
  bool get hasVehicle => widget.vehicles.any((v) => v['driver_id'] == myId);

  JsonRow? get active => widget.trips
      .where(
        (t) =>
            t['driver_id'] == myId && assignedStatuses.contains(t.tripStatus),
      )
      .firstOrNull;

  JsonRow? get finished {
    final t = latestCompleted(
      widget.trips.where((t) => t['driver_id'] == myId),
    );
    if (t == null || dismissed.contains(t['id'])) return null;
    final at = DateTime.tryParse('${t['completed_at'] ?? ''}');
    return at == null || DateTime.now().difference(at).inMinutes < 30
        ? t
        : null;
  }

  List<JsonRow> get requests {
    final list = widget.trips.where((t) => t.tripStatus == 'pending').toList();
    if (myPos != null) {
      double d(JsonRow t) =>
          t.pickup == null ? 1e9 : haversine(myPos!, t.pickup!);
      list.sort((a, b) => d(a).compareTo(d(b)));
    }
    return list;
  }

  int get earningsToday {
    final today = DateTime.now();
    return widget.trips
        .where((t) => t['driver_id'] == myId && t.tripStatus == 'completed')
        .where((t) {
          final at = DateTime.tryParse('${t['completed_at'] ?? ''}')?.toLocal();
          return at != null &&
              at.year == today.year &&
              at.month == today.month &&
              at.day == today.day;
        })
        .fold(0, (sum, t) => sum + (t.fareCents ?? 0));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    knownRequests = requests.length;
    final last = widget.tracker?.lastPosition;
    if (last != null) myPos = last;
    if (online || active != null) {
      startTracking();
    } else {
      locateOnce();
    }
    heartbeat = Timer.periodic(const Duration(seconds: 60), (_) => beat());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (online || active != null)) {
      startTracking();
    }
  }

  @override
  void didUpdateWidget(DriverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final count = requests.length;
    if (online && active == null && count > knownRequests) {
      HapticFeedback.heavyImpact();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.notify('Nueva solicitud de viaje cerca de ti.'),
      );
    }
    knownRequests = count;
    final p = widget.tracker?.lastPosition;
    if (p != null && p != myPos) setState(() => myPos = p);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    heartbeat?.cancel();
    super.dispose();
  }

  Future<void> locateOnce() async {
    try {
      final device = widget.tracker?.device;
      if (device == null) return;
      await device.requestPermission();
      final p = await device.current();
      if (mounted) setState(() => myPos = p);
    } catch (_) {
      if (mounted && repo.demo) {
        setState(() => myPos ??= const Coordinates(4.3365, -74.3638));
      }
    }
  }

  /// Comparte la ubicación mientras está conectado o con un viaje asignado.
  Future<void> startTracking() async {
    final tracker = widget.tracker;
    try {
      if (tracker == null) {
        throw const AppFailure('GPS no disponible en esta sesión.');
      }
      await tracker.start(
        onError: (text) {
          if (mounted) setState(() => gpsNotice = text);
        },
      );
      if (mounted) {
        setState(() {
          myPos = tracker.lastPosition ?? myPos;
          gpsNotice = null;
        });
      }
    } catch (e) {
      if (repo.demo) {
        // Sin GPS en la demostración: ubicación de referencia en Fusagasugá.
        myPos ??= const Coordinates(4.3365, -74.3638);
        try {
          await repo.command('save_location', {
            'p_latitude': myPos!.latitude,
            'p_longitude': myPos!.longitude,
          });
        } catch (_) {}
        if (mounted) setState(() => gpsNotice = null);
      } else if (mounted) {
        setState(
          () => gpsNotice = e is AppFailure
              ? e.message
              : 'Activa el GPS para recibir viajes.',
        );
      }
    }
  }

  Future<void> beat() async {
    final p = widget.tracker?.lastPosition ?? myPos;
    if (p == null || !(online || active != null)) return;
    try {
      await repo.command('save_location', {
        'p_latitude': p.latitude,
        'p_longitude': p.longitude,
      });
    } catch (_) {}
  }

  Future<void> setOnline(bool value) async {
    if (value && !hasVehicle) {
      widget.notify('Registra tu vehículo para conectarte.');
      widget.onEditVehicle();
      return;
    }
    final ok = await widget.run(
      () => repo.command('set_availability', {'p_available': value}),
      success: value
          ? 'Estás conectado. Te avisaremos cuando haya viajes.'
          : 'Te desconectaste.',
    );
    if (!ok) return;
    if (value) {
      await startTracking();
    } else if (active == null) {
      await widget.tracker?.stop();
    }
  }

  Future<void> transition(JsonRow trip, String status, {String? success}) =>
      widget.run(
        () => repo.command('transition_trip', {
          'p_id': trip['id'],
          'p_status': status,
        }),
        success: success,
      );

  Future<void> accept(JsonRow trip) async {
    final ok = await widget.run(
      () => repo.command('transition_trip', {
        'p_id': trip['id'],
        'p_status': 'accepted',
      }),
      success: 'Viaje aceptado. Dirígete al punto de recogida.',
    );
    if (ok) await startTracking();
  }

  Future<void> release(JsonRow trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar este viaje?'),
        content: const Text(
          'La solicitud volverá a estar disponible para otros conductores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar viaje'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await transition(trip, 'pending', success: 'Liberaste el viaje.');
    }
  }

  Future<void> navigateTo(Coordinates point) async {
    final opened = await widget.navigation?.navigateToPoint(point) ?? false;
    if (!opened) {
      widget.notify('No se pudo abrir Waze. Sigue la ruta en el mapa.');
    }
  }

  JsonRow? person(dynamic id) =>
      widget.users.where((u) => u['id'] == id).firstOrNull;

  List<LatLng> legFor(JsonRow trip) {
    final status = trip.tripStatus;
    final from = status == 'in_progress' ? trip.pickup : myPos;
    final to = status == 'in_progress' ? trip.dropoff : trip.pickup;
    if (from == null || to == null) return const [];
    final key = '${trip['id']}-${status == 'in_progress' ? 'trip' : 'pickup'}';
    final cached = legRoutes[key];
    if (cached != null) return cached;
    legRoutes[key] = [latLng(from), latLng(to)];
    widget.planner
        ?.route(from, to)
        .then((r) {
          if (mounted) {
            setState(() => legRoutes[key] = r.points.map(latLng).toList());
          }
        })
        .catchError((_) {});
    return legRoutes[key]!;
  }

  @override
  Widget build(BuildContext context) {
    final trip = active, done = trip == null ? finished : null;
    final pins = <MapPin>[];
    var line = <LatLng>[];
    if (myPos != null) {
      pins.add(MapPin('me', latLng(myPos!), PinKind.car, 'Tu ubicación'));
    }
    if (trip != null) {
      if (trip.pickup != null && trip.tripStatus != 'in_progress') {
        pins.add(
          MapPin('pickup', latLng(trip.pickup!), PinKind.pickup, 'Recogida'),
        );
      }
      if (trip.dropoff != null) {
        pins.add(
          MapPin('dropoff', latLng(trip.dropoff!), PinKind.dropoff, 'Destino'),
        );
      }
      line = legFor(trip);
    } else if (online) {
      for (final r in requests.take(8)) {
        if (r.pickup != null) {
          pins.add(
            MapPin(
              'req${r['id']}',
              latLng(r.pickup!),
              PinKind.request,
              'Solicitud',
            ),
          );
        }
      }
    }
    final panel = trip != null
        ? activePanel(trip)
        : done != null
        ? finishedPanel(done)
        : online
        ? onlinePanel()
        : offlinePanel();
    return LayoutBuilder(
      builder: (context, bounds) => Stack(
        children: [
          Positioned.fill(
            child: RideMap(
              key: mapKey,
              pins: pins,
              route: line,
              focus: myPos == null ? null : latLng(myPos!),
              fitKey: trip != null
                  ? 'trip-${trip['id']}-${trip.tripStatus}'
                  : 'home-$online-${myPos != null}',
              bottomInset: bounds.maxHeight * .45,
              onLocate: () {
                if (myPos != null) mapKey.currentState?.moveTo(latLng(myPos!));
                startTracking();
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    Flexible(
                      child: Material(
                        color: online ? const Color(0xFF16A06A) : ink,
                        borderRadius: BorderRadius.circular(30),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                online
                                    ? Icons.wifi_tethering_rounded
                                    : Icons.power_settings_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  online ? 'Conectado' : 'Desconectado',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          'Hoy ${formatCop(earningsToday)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: bounds.maxHeight * .7),
              child: SingleChildScrollView(
                reverse: true,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(
                      trip != null
                          ? 'a${trip['id']}${trip.tripStatus}'
                          : done != null
                          ? 'f${done['id']}'
                          : 'o$online',
                    ),
                    child: panel,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget offlinePanel() => BottomPanel(
    children: [
      const Text(
        'Estás desconectado',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        hasVehicle
            ? 'Conéctate para recibir solicitudes de viaje cerca de ti.'
            : 'Registra tu vehículo para empezar a recibir viajes.',
        style: const TextStyle(color: muted),
      ),
      if (gpsNotice != null) ...[
        const SizedBox(height: 8),
        Text(gpsNotice!, style: const TextStyle(color: orange, fontSize: 13)),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('go-online'),
        onPressed: widget.busy ? null : () => setOnline(true),
        style: FilledButton.styleFrom(
          backgroundColor: electric,
          minimumSize: const Size(0, 58),
        ),
        icon: const Icon(Icons.power_settings_new_rounded),
        label: Text(hasVehicle ? 'Conectarme' : 'Registrar vehículo'),
      ),
    ],
  );

  Widget onlinePanel() {
    final list = requests;
    return BottomPanel(
      children: [
        Row(
          children: [
            const PulseRadar(size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.isEmpty
                        ? 'Buscando viajes…'
                        : '${list.length} ${list.length == 1 ? 'solicitud' : 'solicitudes'} cerca',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    gpsNotice ?? 'Mantén la app abierta para recibir viajes.',
                    style: TextStyle(
                      color: gpsNotice == null ? muted : orange,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: widget.busy ? null : () => setOnline(false),
              child: const Text('Desconectarme'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final r in list.take(4)) requestCard(r),
      ],
    );
  }

  Widget requestCard(JsonRow r) {
    final toPickup = myPos != null && r.pickup != null
        ? haversine(myPos!, r.pickup!)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E6F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F15233D),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                r.fareCents == null ? 'Tarifa mínima' : formatCop(r.fareCents!),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: canvas,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r.paymentMethod == 'cash' ? 'Efectivo' : 'Pago digital',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (toPickup != null)
                Text(
                  'A ${etaMinutes(toPickup)} min · ${distanceLabel(toPickup)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: electric,
                  ),
                ),
            ],
          ),
          if (r.distanceMeters != null)
            Text(
              'Viaje de ${distanceLabel(r.distanceMeters!)}${r.durationSeconds == null ? '' : ' · ${durationLabel(r.durationSeconds!)}'}',
              style: const TextStyle(color: muted, fontSize: 12.5),
            ),
          const SizedBox(height: 10),
          RouteStops(
            origin: '${r['origin']}',
            destination: '${r['destination']}',
            dense: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.busy
                      ? null
                      : () => widget.run(
                          () => repo.command('reject_trip', {'p_id': r['id']}),
                        ),
                  child: const Text('Ignorar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: Key('accept-${r['id']}'),
                  onPressed: widget.busy ? null : () => accept(r),
                  style: FilledButton.styleFrom(backgroundColor: ink),
                  child: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget activePanel(JsonRow trip) {
    final status = trip.tripStatus;
    final passenger = person(trip['passenger_id']);
    final name = '${passenger?['name'] ?? 'Pasajero'}'.split(' ').first;
    final target = status == 'in_progress' ? trip.dropoff : trip.pickup;
    final distance = myPos != null && target != null
        ? haversine(myPos!, target)
        : null;
    final arrivedAt = DateTime.tryParse('${trip['arrived_at'] ?? ''}');
    final waiting = arrivedAt == null
        ? null
        : DateTime.now().difference(arrivedAt).inMinutes;
    final (title, subtitle) = switch (status) {
      'accepted' => (
        'Recoge a $name',
        distance == null
            ? '${trip['origin']}'
            : 'A ${etaMinutes(distance)} min · ${trip['origin']}',
      ),
      'arrived' => (
        'Esperando a $name',
        waiting == null || waiting < 1
            ? 'Le avisamos que llegaste.'
            : 'Esperando hace $waiting min.',
      ),
      _ => (
        'Llevando a $name',
        distance == null
            ? '${trip['destination']}'
            : 'Faltan ${etaMinutes(distance)} min · ${trip['destination']}',
      ),
    };
    final (action, next, success) = switch (status) {
      'accepted' => (
        'Llegué al punto',
        'arrived',
        'Avisamos al pasajero que llegaste.',
      ),
      'arrived' => ('Iniciar viaje', 'in_progress', 'Viaje iniciado.'),
      _ => ('Finalizar viaje', 'completed', 'Viaje finalizado.'),
    };
    return BottomPanel(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: mist,
              child: Text(
                name.substring(0, 1),
                style: const TextStyle(fontWeight: FontWeight.w900, color: ink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${passenger?['name'] ?? 'Pasajero'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            if (trip.fareCents != null)
              Text(
                formatCop(trip.fareCents!),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            if ('${passenger?['phone'] ?? ''}'.isNotEmpty &&
                widget.navigation != null) ...[
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Llamar',
                onPressed: () =>
                    widget.navigation!.call('${passenger!['phone']}'),
                icon: const Icon(Icons.call_rounded),
              ),
            ],
          ],
        ),
        const Divider(height: 26),
        RouteStops(
          origin: '${trip['origin']}',
          destination: '${trip['destination']}',
          dense: true,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (target != null && widget.navigation != null) ...[
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () => navigateTo(target),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const FittedBox(child: Text('Navegar')),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 3,
              child: FilledButton(
                key: Key('driver-$next'),
                onPressed: widget.busy
                    ? null
                    : () => transition(trip, next, success: success),
                style: FilledButton.styleFrom(
                  backgroundColor: status == 'in_progress'
                      ? const Color(0xFFE0483E)
                      : ink,
                ),
                child: Text(action),
              ),
            ),
          ],
        ),
        if (status != 'in_progress')
          TextButton(
            onPressed: widget.busy ? null : () => release(trip),
            child: const Text('Cancelar viaje'),
          ),
      ],
    );
  }

  Widget finishedPanel(JsonRow trip) => BottomPanel(
    children: [
      const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF16A06A),
        size: 46,
      ),
      const SizedBox(height: 6),
      const Text(
        'Viaje completado',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      Text(
        trip.paymentMethod == 'cash'
            ? 'Cobra en efectivo'
            : 'El pasajero paga con tarjeta, Nequi o PSE',
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted),
      ),
      const SizedBox(height: 6),
      Text(
        trip.fareCents == null ? '—' : formatCop(trip.fareCents!),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: () => setState(() => dismissed.add('${trip['id']}')),
        style: FilledButton.styleFrom(backgroundColor: ink),
        child: const Text('Listo, buscar otro viaje'),
      ),
    ],
  );
}
