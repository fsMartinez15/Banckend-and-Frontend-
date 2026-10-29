import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../domain/external_navigation.dart';
import '../domain/fare.dart';
import '../domain/ride_repository.dart';
import '../domain/route_planner.dart';
import 'place_search_page.dart';
import 'ride_map.dart';
import 'ride_theme.dart';
import 'ride_widgets.dart';

typedef RunAction =
    Future<bool> Function(Future<void> Function() action, {String? success});

/// Inicio del pasajero tipo Uber: mapa a pantalla completa y un panel que
/// cambia según el viaje (elegir destino → tarifa → buscando → conductor en
/// camino → llegó → en viaje → pagar y calificar).
class PassengerScreen extends StatefulWidget {
  final RideRepository repository;
  final RoutePlanner? planner;
  final LocationDevice? device;
  final ExternalNavigation? navigation;
  final JsonRow me;
  final List<JsonRow> trips, users, vehicles, locations, payments;
  final bool busy;
  final RunAction run;
  final void Function(String) notify;
  const PassengerScreen({
    super.key,
    required this.repository,
    required this.me,
    required this.trips,
    required this.users,
    required this.vehicles,
    required this.locations,
    required this.payments,
    required this.busy,
    required this.run,
    required this.notify,
    this.planner,
    this.device,
    this.navigation,
  });
  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  RideRepository get repo => widget.repository;
  Coordinates? myPos;
  String originName = 'Mi ubicación';
  bool locating = false;
  String? gpsNotice;
  RoutePlace? origin, destination;
  RoadRoute? route;
  bool routing = false, approximate = false;
  String payment = 'cash';
  Tariff tariff = Tariff.standard;
  List<Coordinates> nearby = [];
  Timer? nearbyTimer;
  final dismissed = <String>{};
  final tripRoutes = <String, List<LatLng>>{};
  int stars = 5;
  final comment = TextEditingController();
  String? lastStatus;

  JsonRow? get active => widget.trips
      .where((t) => t['passenger_id'] == widget.me['id'] && t.isActiveTrip)
      .firstOrNull;

  /// Viaje recién terminado que falta calificar o pagar.
  JsonRow? get finished {
    final t = latestCompleted(
      widget.trips.where((t) => t['passenger_id'] == widget.me['id']),
    );
    if (t == null || dismissed.contains(t['id'])) return null;
    final at = DateTime.tryParse('${t['completed_at'] ?? ''}');
    final recent = at == null || DateTime.now().difference(at).inHours < 3;
    return recent && (t['rating'] == null || needsPayment(t)) ? t : null;
  }

  bool isPaid(JsonRow t) => widget.payments.any(
    (p) => p['trip_id'] == t['id'] && p['status'] == 'APPROVED',
  );
  bool needsPayment(JsonRow t) => t.paymentMethod == 'wompi' && !isPaid(t);

  Coordinates get here => myPos ?? const Coordinates(4.3365, -74.3638);

  @override
  void initState() {
    super.initState();
    lastStatus = active?.tripStatus;
    locate();
    repo
        .tariff()
        .then((t) {
          if (mounted) setState(() => tariff = t);
        })
        .catchError((_) {});
    loadNearby();
    nearbyTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => loadNearby(),
    );
  }

  @override
  void didUpdateWidget(PassengerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = active?.tripStatus;
    if (status != lastStatus) {
      final message = switch (status) {
        'accepted' => '¡Un conductor aceptó tu viaje! Va en camino.',
        'arrived' => 'Tu conductor llegó al punto de recogida.',
        'in_progress' => 'Tu viaje comenzó. ¡Buen camino!',
        'pending' when lastStatus != null && lastStatus != 'pending' =>
          'El conductor no pudo continuar. Buscamos otro cerca de ti.',
        _ => null,
      };
      if (message != null) {
        HapticFeedback.heavyImpact();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.notify(message),
        );
      }
      if (lastStatus == 'in_progress' && status == null) {
        stars = 5;
        comment.clear();
      }
      lastStatus = status;
    }
  }

  @override
  void dispose() {
    nearbyTimer?.cancel();
    comment.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    final device = widget.device;
    setState(() {
      locating = true;
      gpsNotice = null;
    });
    try {
      if (device == null) throw const AppFailure('GPS no disponible');
      await device.requestPermission();
      final p = await device.current();
      if (!mounted) return;
      setState(() => myPos = p);
      mapKey.currentState?.moveTo(latLng(p));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (repo.demo) myPos ??= const Coordinates(4.33930, -74.36420);
        gpsNotice = e is AppFailure && e.message != 'GPS no disponible'
            ? e.message
            : 'Activa tu ubicación para recogerte donde estás.';
      });
    } finally {
      if (mounted) setState(() => locating = false);
    }
    final p = myPos, planner = widget.planner;
    if (p != null && planner != null) {
      try {
        final name = await planner.reverse(p);
        if (mounted && name != null) setState(() => originName = name);
      } catch (_) {}
    }
    loadNearby();
  }

  Future<void> loadNearby() async {
    if (active != null) return;
    try {
      final cars = await repo.nearbyDrivers(origin?.point ?? here);
      if (mounted) setState(() => nearby = cars);
    } catch (_) {}
  }

  Future<void> openSearch() async {
    final choice = await Navigator.of(context).push<PlaceChoice>(
      MaterialPageRoute(
        builder: (_) => PlaceSearchPage(
          planner: widget.planner,
          originLabel: originName,
          near: here,
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      origin = choice.origin;
      destination = choice.destination;
    });
    await planRoute();
  }

  Future<void> quickDestination(RoutePlace place) async {
    setState(() {
      origin = null;
      destination = place;
    });
    await planRoute();
  }

  Coordinates get pickupPoint => origin?.point ?? here;
  String get pickupName => origin?.name ?? originName;

  Future<void> planRoute() async {
    final to = destination;
    if (to == null) return;
    setState(() {
      routing = true;
      route = null;
      approximate = false;
    });
    try {
      final planner = widget.planner;
      if (planner == null) throw const AppFailure('Sin servicio de rutas');
      final result = await planner.route(pickupPoint, to.point);
      if (mounted) setState(() => route = result);
    } catch (_) {
      final straight = haversine(pickupPoint, to.point);
      if (mounted) {
        setState(() {
          approximate = true;
          route = RoadRoute(
            points: [pickupPoint, to.point],
            steps: const [],
            meters: straight * 1.3,
            seconds: straight * 1.3 / (24000 / 3600),
          );
        });
      }
    } finally {
      if (mounted) setState(() => routing = false);
    }
    loadNearby();
  }

  void clearPlan() => setState(() {
    destination = null;
    origin = null;
    route = null;
  });

  Future<void> requestRide() async {
    final to = destination, r = route;
    if (to == null || r == null) return;
    if (haversine(pickupPoint, to.point) < 80) {
      widget.notify('El destino está demasiado cerca del punto de recogida.');
      return;
    }
    final ok = await widget.run(() async {
      await repo.command('request_trip', {
        'p_origin': pickupName.length < 3 ? 'Mi ubicación' : pickupName,
        'p_destination': to.name,
        'p_origin_lat': pickupPoint.latitude,
        'p_origin_lng': pickupPoint.longitude,
        'p_destination_lat': to.point.latitude,
        'p_destination_lng': to.point.longitude,
        'p_distance_m': r.meters.round(),
        'p_duration_s': r.seconds.round(),
        'p_payment_method': payment,
      });
    });
    if (ok && mounted) {
      setState(() {
        destination = null;
        origin = null;
        route = null;
      });
    }
  }

  Future<void> cancelRide(JsonRow trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar el viaje?'),
        content: Text(
          trip.tripStatus == 'pending'
              ? 'Dejaremos de buscar conductor.'
              : 'Tu conductor ya va en camino. ¿Seguro que quieres cancelar?',
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
    if (confirm != true) return;
    await widget.run(
      () => repo.command('transition_trip', {
        'p_id': trip['id'],
        'p_status': 'cancelled',
      }),
      success: 'Viaje cancelado.',
    );
  }

  Future<void> pay(JsonRow trip) async {
    await widget.run(() async {
      final url = await repo.checkoutUrl('${trip['id']}');
      if (url.startsWith('demo:')) {
        widget.notify('Pago simulado aprobado (demostración).');
        return;
      }
      final opened = await widget.navigation?.openUrl(url) ?? false;
      if (!opened) {
        throw const AppFailure('No se pudo abrir la página de pago de Wompi.');
      }
      widget.notify(
        'Completa el pago en Wompi. Al volver, verás el viaje como pagado.',
      );
    });
  }

  Future<void> submitRating(JsonRow trip) async {
    final ok = await widget.run(
      () => repo.command('rate_trip', {
        'p_id': trip['id'],
        'p_rating': stars,
        'p_comment': comment.text.trim(),
      }),
      success: '¡Gracias por calificar!',
    );
    if (ok && mounted && !needsPayment(trip)) {
      setState(() => dismissed.add('${trip['id']}'));
    }
  }

  JsonRow? person(dynamic id) =>
      widget.users.where((u) => u['id'] == id).firstOrNull;
  JsonRow? car(dynamic id) =>
      widget.vehicles.where((v) => v['driver_id'] == id).firstOrNull;
  Coordinates? driverAt(dynamic id) {
    final p = widget.locations.where((l) => l['driver_id'] == id).firstOrNull;
    return p == null
        ? null
        : Coordinates(
            (p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble(),
          );
  }

  /// Ruta por calles del viaje activo (se calcula una vez por viaje).
  List<LatLng> routeFor(JsonRow trip) {
    final id = '${trip['id']}', a = trip.pickup, b = trip.dropoff;
    if (a == null || b == null) return const [];
    final cached = tripRoutes[id];
    if (cached != null) return cached;
    tripRoutes[id] = [latLng(a), latLng(b)];
    widget.planner
        ?.route(a, b)
        .then((r) {
          if (mounted) {
            setState(() => tripRoutes[id] = r.points.map(latLng).toList());
          }
        })
        .catchError((_) {});
    return tripRoutes[id]!;
  }

  final mapKey = GlobalKey<RideMapState>();

  @override
  Widget build(BuildContext context) {
    final trip = active, done = trip == null ? finished : null;
    final driverPos = trip == null ? null : driverAt(trip['driver_id']);
    final pins = <MapPin>[];
    var line = <LatLng>[];
    Object fitKey;
    if (trip != null) {
      if (trip.pickup != null) {
        pins.add(
          MapPin(
            'pickup',
            latLng(trip.pickup!),
            PinKind.pickup,
            'Punto de recogida',
          ),
        );
      }
      if (trip.dropoff != null) {
        pins.add(
          MapPin('dropoff', latLng(trip.dropoff!), PinKind.dropoff, 'Destino'),
        );
      }
      if (driverPos != null && trip.tripStatus != 'pending') {
        pins.add(MapPin('car', latLng(driverPos), PinKind.car, 'Tu conductor'));
      }
      line = routeFor(trip);
      fitKey = 'trip-${trip['id']}-${trip.tripStatus}-${driverPos != null}';
    } else {
      if (myPos != null) {
        pins.add(MapPin('me', latLng(myPos!), PinKind.me, 'Tu ubicación'));
      }
      if (destination != null) {
        pins
          ..add(
            MapPin('pickup', latLng(pickupPoint), PinKind.pickup, 'Recogida'),
          )
          ..add(
            MapPin(
              'dropoff',
              latLng(destination!.point),
              PinKind.dropoff,
              'Destino',
            ),
          );
        line = route?.points.map(latLng).toList() ?? const [];
      }
      for (final (i, c) in nearby.indexed) {
        pins.add(
          MapPin('near$i', latLng(c), PinKind.nearbyCar, 'Conductor cercano'),
        );
      }
      fitKey = destination == null
          ? 'idle-${myPos != null}'
          : 'plan-${destination!.name}-${route != null}';
    }
    final panel = trip != null
        ? activePanel(trip, driverPos)
        : done != null
        ? finishedPanel(done)
        : destination != null
        ? previewPanel()
        : idlePanel();
    return LayoutBuilder(
      builder: (context, bounds) => Stack(
        children: [
          Positioned.fill(
            child: RideMap(
              key: mapKey,
              pins: pins,
              route: line,
              focus: latLng(here),
              fitKey: fitKey,
              bottomInset: bounds.maxHeight * .42,
              onLocate: locate,
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
                    if (destination != null && trip == null)
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          tooltip: 'Volver',
                          onPressed: clearPlan,
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: ink,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: Material(
                          color: Colors.white,
                          elevation: 3,
                          borderRadius: BorderRadius.circular(30),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.near_me_rounded,
                                  color: electric,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Hola, ${'${widget.me['name']}'.split(' ').first}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (repo.demo)
                      const Chip(
                        label: Text(
                          'DEMO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
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
              constraints: BoxConstraints(maxHeight: bounds.maxHeight * .72),
              child: SingleChildScrollView(
                reverse: true,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(panelKey(trip, done)),
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

  String panelKey(JsonRow? trip, JsonRow? done) => trip != null
      ? 'a-${trip['id']}-${trip.tripStatus}'
      : done != null
      ? 'f-${done['id']}'
      : destination != null
      ? 'p'
      : 'i';

  Widget idlePanel() {
    final closest = nearby.isEmpty
        ? null
        : nearby.map((c) => haversine(c, here)).reduce((a, b) => a < b ? a : b);
    return BottomPanel(
      children: [
        const Text(
          '¿A dónde vas?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          key: const Key('where-to'),
          borderRadius: BorderRadius.circular(18),
          onTap: openSearch,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: canvas,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded, color: ink),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Buscar destino',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
                Icon(Icons.schedule_rounded, color: muted, size: 18),
                SizedBox(width: 4),
                Text(
                  'Ahora',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in frequentPlaces)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.place_outlined, size: 17),
                    label: Text(p.name),
                    onPressed: () => quickDestination(p),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              gpsNotice == null
                  ? Icons.radio_button_checked
                  : Icons.location_disabled_rounded,
              size: 16,
              color: gpsNotice == null ? electric : orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                locating
                    ? 'Buscando tu ubicación…'
                    : gpsNotice ?? 'Te recogemos en $originName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: muted),
              ),
            ),
          ],
        ),
        if (closest != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.directions_car_filled_rounded,
                size: 16,
                color: ink,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${nearby.length} conductores cerca · el más cercano a ${etaMinutes(closest)} min',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget previewPanel() {
    final r = route;
    final fare = r == null ? null : tariff.estimate(r.meters, r.seconds);
    final closest = nearby.isEmpty
        ? null
        : nearby
              .map((c) => haversine(c, pickupPoint))
              .reduce((a, b) => a < b ? a : b);
    return BottomPanel(
      children: [
        RouteStops(
          origin: pickupName,
          destination: destination!.name,
          dense: true,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: mist,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: electric, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: ink,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RideMove',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      r == null
                          ? 'Calculando ruta…'
                          : '${durationLabel(r.seconds)} · ${distanceLabel(r.meters)}${closest == null ? '' : ' · llega en ${etaMinutes(closest)} min'}',
                      style: const TextStyle(color: muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (fare != null)
                Text(
                  formatCop(fare),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                )
              else
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        if (approximate)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Ruta aproximada: no pudimos consultar las calles. La tarifa se ajusta al solicitar.',
              style: TextStyle(fontSize: 11.5, color: muted),
            ),
          ),
        const SizedBox(height: 14),
        PaymentSelector(
          value: payment,
          onChanged: (v) => setState(() => payment = v),
        ),
        const SizedBox(height: 14),
        FilledButton(
          key: const Key('request-ride'),
          onPressed: r == null || routing || widget.busy ? null : requestRide,
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            minimumSize: const Size(0, 58),
          ),
          child: Text(
            fare == null
                ? 'Solicitar RideMove'
                : 'Solicitar RideMove · ${formatCop(fare)}',
          ),
        ),
      ],
    );
  }

  Widget activePanel(JsonRow trip, Coordinates? driverPos) {
    final status = trip.tripStatus;
    final driver = person(trip['driver_id']), vehicle = car(trip['driver_id']);
    final pickup = trip.pickup, dropoff = trip.dropoff;
    String title, subtitle;
    switch (status) {
      case 'pending':
        title = 'Buscando conductor';
        subtitle = 'Estamos conectándote con el conductor más cercano.';
      case 'accepted':
        final eta = driverPos != null && pickup != null
            ? etaMinutes(haversine(driverPos, pickup))
            : null;
        title = eta == null ? 'Tu conductor va en camino' : 'Llega en $eta min';
        subtitle = 'Espera en ${trip['origin']}';
      case 'arrived':
        title = 'Tu conductor llegó';
        subtitle =
            'Te espera en ${trip['origin']}. Verifica la placa antes de subir.';
      default:
        final eta = driverPos != null && dropoff != null
            ? etaMinutes(haversine(driverPos, dropoff))
            : null;
        final at = DateTime.now().add(
          Duration(minutes: eta ?? (trip.durationSeconds ?? 600) ~/ 60),
        );
        title = 'En viaje a ${trip['destination']}';
        subtitle =
            'Llegada aprox. ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    }
    return BottomPanel(
      children: [
        if (status == 'pending') const Center(child: PulseRadar()),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(subtitle, style: const TextStyle(color: muted)),
                ],
              ),
            ),
            if (status == 'arrived')
              const Icon(Icons.emoji_people_rounded, color: electric, size: 34),
          ],
        ),
        if (status != 'pending') ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: switch (status) {
                'accepted' => .33,
                'arrived' => .55,
                _ => .8,
              },
              minHeight: 4,
              backgroundColor: mist,
            ),
          ),
          const SizedBox(height: 16),
          DriverCard(
            driver: driver,
            vehicle: vehicle,
            onCall:
                '${driver?['phone'] ?? ''}'.isEmpty || widget.navigation == null
                ? null
                : () => widget.navigation!.call('${driver!['phone']}'),
          ),
        ],
        const Divider(height: 28),
        RouteStops(
          origin: '${trip['origin']}',
          destination: '${trip['destination']}',
          dense: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              trip.paymentMethod == 'cash'
                  ? Icons.payments_outlined
                  : Icons.credit_card_rounded,
              size: 18,
              color: muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                paymentLabels[trip.paymentMethod] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted),
              ),
            ),
            if (trip.fareCents != null)
              Text(
                formatCop(trip.fareCents!),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        if (status != 'in_progress') ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: widget.busy ? null : () => cancelRide(trip),
            child: Text(
              status == 'pending' ? 'Cancelar solicitud' : 'Cancelar viaje',
            ),
          ),
        ],
      ],
    );
  }

  Widget finishedPanel(JsonRow trip) {
    final driver = person(trip['driver_id']);
    final fare = trip.fareCents;
    final unpaid = needsPayment(trip);
    return BottomPanel(
      children: [
        const Text(
          '¡Llegaste a tu destino!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 4),
        Text('${trip['destination']}', style: const TextStyle(color: muted)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: canvas,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        color: muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      fare == null ? '—' : formatCop(fare),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trip.paymentMethod == 'cash'
                    ? 'Efectivo'
                    : isPaid(trip)
                    ? 'Pagado ✓'
                    : 'Pendiente de pago',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: unpaid ? orange : const Color(0xFF1C7A55),
                ),
              ),
            ],
          ),
        ),
        if (trip.paymentMethod == 'cash')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Paga en efectivo a ${'${driver?['name'] ?? 'tu conductor'}'.split(' ').first}.',
              style: const TextStyle(color: muted, fontSize: 13),
            ),
          ),
        if (unpaid) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.busy ? null : () => pay(trip),
            icon: const Icon(Icons.lock_rounded, size: 18),
            label: Text(
              'Pagar ${fare == null ? '' : formatCop(fare)} con Wompi',
            ),
          ),
        ],
        if (trip['rating'] == null) ...[
          const SizedBox(height: 16),
          Text(
            '¿Cómo estuvo tu viaje con ${'${driver?['name'] ?? 'tu conductor'}'.split(' ').first}?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          StarRating(value: stars, onChanged: (v) => setState(() => stars = v)),
          TextField(
            controller: comment,
            maxLength: 255,
            decoration: const InputDecoration(
              hintText: 'Cuéntanos algo (opcional)',
              isDense: true,
            ),
          ),
          FilledButton(
            onPressed: widget.busy ? null : () => submitRating(trip),
            style: FilledButton.styleFrom(backgroundColor: ink),
            child: const Text('Enviar calificación'),
          ),
        ],
        TextButton(
          onPressed: () => setState(() => dismissed.add('${trip['id']}')),
          child: Text(unpaid || trip['rating'] == null ? 'Ahora no' : 'Listo'),
        ),
      ],
    );
  }
}
