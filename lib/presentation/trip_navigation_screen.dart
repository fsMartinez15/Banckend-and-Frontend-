import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../application/location_tracker.dart';
import '../domain/ride_repository.dart';
import '../domain/external_navigation.dart';
import '../domain/route_planner.dart';
import 'route_summary.dart';
import 'city_map.dart';
import 'ride_theme.dart';

/// Computes a street route inside RideMove; Waze remains an optional action.
class TripNavigationScreen extends StatefulWidget {
  final JsonRow trip;
  final RideRepository repository;
  final LocationTracker? tracker;
  final ExternalNavigation? navigation;
  final RoutePlanner? routePlanner;
  const TripNavigationScreen({
    super.key,
    required this.trip,
    required this.repository,
    this.tracker,
    this.navigation,
    this.routePlanner,
  });
  @override
  State<TripNavigationScreen> createState() => _TripNavigationScreenState();
}

class _TripNavigationScreenState extends State<TripNavigationScreen>
    with WidgetsBindingObserver {
  LatLng? position;
  Timer? timer;
  bool busy = false, gps = false, refreshing = false;
  String? notice;
  RoadRoute? roadRoute;
  RoutePlace? routeOrigin, routeDestination;
  bool planning = false;
  String? routeError, selecting;
  String get destination => '${widget.trip['destination']}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refreshPosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) calculateRoute();
    });
    timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => refreshPosition(),
    );
  }

  Future<RoutePlace?> resolvePlace(String text, String kind) async {
    final candidates = await widget.routePlanner!.search(text);
    if (!mounted) return null;
    if (candidates.length == 1) return candidates.single;
    if (candidates.isEmpty) {
      setState(() {
        selecting = kind;
        routeError =
            'No encontramos "$text". Marca el lugar exacto en el mapa.';
      });
      return null;
    }
    final place = await showModalBottomSheet<RoutePlace>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              kind == 'origin'
                  ? 'Elige el punto de partida'
                  : 'Elige el destino',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...candidates.map(
              (p) => ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(p.name),
                subtitle: Text(p.address),
                onTap: () => Navigator.pop(context, p),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Marcar en el mapa'),
            ),
          ],
        ),
      ),
    );
    if (place == null && mounted) setState(() => selecting = kind);
    return place;
  }

  Future<void> calculateRoute() async {
    if (planning) return;
    setState(() {
      planning = true;
      routeError = null;
      roadRoute = null;
    });
    try {
      if (widget.routePlanner == null) {
        throw const AppFailure('El servicio de rutas no está configurado.');
      }
      routeOrigin ??= await resolvePlace('${widget.trip['origin']}', 'origin');
      if (!mounted || routeOrigin == null) return;
      routeDestination ??= await resolvePlace(destination, 'destination');
      if (!mounted || routeDestination == null) return;
      final result = await widget.routePlanner!.route(
        routeOrigin!.point,
        routeDestination!.point,
      );
      if (mounted) {
        setState(() {
          roadRoute = result;
          selecting = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => routeError = error is AppFailure
              ? error.message
              : 'No se pudo calcular la ruta. Comprueba la conexión o marca los puntos en el mapa.',
        );
      }
    } finally {
      if (mounted) setState(() => planning = false);
    }
  }

  void selectPoint(LatLng point) {
    if (selecting == null || planning) return;
    final place = RoutePlace(
      selecting == 'origin' ? 'Origen marcado' : 'Destino marcado',
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
      Coordinates(point.latitude, point.longitude),
    );
    setState(() {
      if (selecting == 'origin') {
        routeOrigin = place;
      } else {
        routeDestination = place;
      }
      selecting = null;
    });
    calculateRoute();
  }

  Future<void> routeFromGps() async {
    await enableGps();
    if (!mounted || !gps || position == null) return;
    routeOrigin = RoutePlace(
      'Tu ubicación actual',
      '',
      Coordinates(position!.latitude, position!.longitude),
    );
    await calculateRoute();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Keep the foreground trip tracker alive when returning to the dashboard.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      widget.tracker?.stop();
      if (mounted) setState(() => gps = false);
    }
  }

  Future<void> refreshPosition() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final locations = await widget.repository.locations();
      final last = locations
          .where((p) => p['driver_id'] == widget.trip['driver_id'])
          .firstOrNull;
      if (mounted && last != null) {
        setState(() {
          position = LatLng(
            (last['latitude'] as num).toDouble(),
            (last['longitude'] as num).toDouble(),
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              notice = 'No se pudo actualizar la posición. Revisa tu conexión.',
        );
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> enableGps() async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      if (widget.tracker == null) {
        throw const AppFailure('GPS no disponible en esta sesión.');
      }
      await widget.tracker!.start(
        onError: (text) {
          if (mounted) {
            setState(() {
              notice = text;
              gps = false;
            });
          }
        },
      );
      final current = widget.tracker!.lastPosition;
      if (mounted) {
        setState(() {
          gps = widget.tracker!.isTracking;
          if (gps && current != null) {
            position = LatLng(current.latitude, current.longitude);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => notice = error is AppFailure
              ? error.message
              : 'No pudimos activar el GPS. Revisa el permiso de ubicación.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openWaze() async {
    try {
      final opened = await widget.navigation?.navigateTo(destination) ?? false;
      if (!opened && mounted) {
        setState(
          () => notice =
              'No se pudo abrir Waze. Comprueba que esté instalado o que tengas navegador.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => notice = 'No se pudo abrir Waze. Inténtalo de nuevo.');
      }
    }
  }

  Future<void> finish() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.repository.command('transition_trip', {
        'p_id': widget.trip['id'],
        'p_status': 'completed',
      });
      await widget.tracker?.stop();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          notice =
              'No se pudo finalizar el viaje. Revisa tu conexión e inténtalo de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ink,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 18, 16),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Volver al inicio',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: electric,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EN CAMINO',
                        style: TextStyle(
                          color: orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        destination,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CityMap(
              driver: position,
              route: roadRoute,
              origin: routeOrigin == null
                  ? null
                  : LatLng(
                      routeOrigin!.point.latitude,
                      routeOrigin!.point.longitude,
                    ),
              destination: routeDestination == null
                  ? null
                  : LatLng(
                      routeDestination!.point.latitude,
                      routeDestination!.point.longitude,
                    ),
              onPointSelected: selecting == null ? null : selectPoint,
            ),
          ),
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.white),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .42,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RouteSummary(
                    route: roadRoute,
                    loading: planning,
                    error: routeError,
                    selecting: selecting,
                    origin: routeOrigin?.name ?? '${widget.trip['origin']}',
                    destination: routeDestination?.name ?? destination,
                    retry: calculateRoute,
                    selectOrigin: () => setState(() => selecting = 'origin'),
                    selectDestination: () =>
                        setState(() => selecting = 'destination'),
                    cancelSelection: () => setState(() => selecting = null),
                  ),
                  Row(
                    children: [
                      Icon(
                        gps ? Icons.gps_fixed : Icons.gps_not_fixed,
                        color: electric,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          gps
                              ? 'GPS activo · viaje en curso'
                              : position == null
                              ? 'Activa el GPS para ubicarte'
                              : 'Última posición recibida',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: busy ? null : enableGps,
                        child: Text(gps ? 'Actualizar GPS' : 'Activar GPS'),
                      ),
                    ],
                  ),
                  if (notice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        notice!,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  if (roadRoute != null)
                    TextButton.icon(
                      onPressed: busy || planning ? null : routeFromGps,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('Recalcular desde mi ubicación'),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: openWaze,
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Navegar con Waze'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La ruta y las indicaciones están en RideMove. Waze es opcional para navegación por voz. Al regresar, reactiva el GPS.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: busy ? null : finish,
                      icon: const Icon(Icons.flag_outlined, size: 19),
                      label: const Text('Finalizar viaje'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
