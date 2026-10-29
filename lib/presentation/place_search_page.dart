import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../domain/ride_repository.dart';
import '../domain/route_planner.dart';
import 'ride_map.dart';
import 'ride_theme.dart';

/// Lugares frecuentes de Fusagasugá (atajos y respaldo sin conexión).
const frequentPlaces = [
  RoutePlace(
    'Plaza Mayor',
    'Centro, Fusagasugá',
    Coordinates(4.34391, -74.36196),
  ),
  RoutePlace(
    'Terminal de transporte',
    'Fusagasugá',
    Coordinates(4.34262, -74.35851),
  ),
  RoutePlace(
    'Universidad de Cundinamarca',
    'Diagonal 18, Fusagasugá',
    Coordinates(4.33598, -74.37123),
  ),
  RoutePlace(
    'Centro comercial Manila',
    'Fusagasugá',
    Coordinates(4.33930, -74.36420),
  ),
];

class PlaceChoice {
  final RoutePlace? origin; // null = ubicación actual
  final RoutePlace destination;
  const PlaceChoice(this.origin, this.destination);
}

/// Pantalla "¿A dónde vas?": origen (por defecto tu ubicación) y destino con
/// búsqueda mientras escribes, atajos y opción de marcar en el mapa.
class PlaceSearchPage extends StatefulWidget {
  final RoutePlanner? planner;
  final String originLabel;
  final Coordinates? near;
  const PlaceSearchPage({
    super.key,
    required this.planner,
    required this.originLabel,
    this.near,
  });
  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final originText = TextEditingController();
  final destinationText = TextEditingController();
  final destinationFocus = FocusNode(), originFocus = FocusNode();
  RoutePlace? origin;
  String editing = 'destination';
  List<RoutePlace> results = [];
  bool searching = false;
  String? error;
  Timer? debounce;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    originFocus.addListener(() {
      if (originFocus.hasFocus) setState(() => editing = 'origin');
    });
    destinationFocus.addListener(() {
      if (destinationFocus.hasFocus) setState(() => editing = 'destination');
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    originText.dispose();
    destinationText.dispose();
    originFocus.dispose();
    destinationFocus.dispose();
    super.dispose();
  }

  void onChanged(String text) {
    debounce?.cancel();
    final query = text.trim();
    if (query.length < 3) {
      setState(() {
        results = [];
        error = null;
      });
      return;
    }
    debounce = Timer(const Duration(milliseconds: 550), () => search(query));
  }

  Future<void> search(String query) async {
    final planner = widget.planner;
    final local = frequentPlaces
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (planner == null) {
      setState(() => results = local);
      return;
    }
    final run = ++generation;
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final found = await planner.search(query);
      if (!mounted || run != generation) return;
      setState(
        () => results = [
          ...local,
          ...found.where((f) => !local.any((l) => l.name == f.name)),
        ],
      );
    } catch (e) {
      if (!mounted || run != generation) return;
      setState(() {
        results = local;
        error = e is AppFailure
            ? e.message
            : 'No pudimos buscar. Revisa tu conexión.';
      });
    } finally {
      if (mounted && run == generation) setState(() => searching = false);
    }
  }

  void choose(RoutePlace place) {
    if (editing == 'origin') {
      setState(() {
        origin = place;
        originText.text = place.name;
        results = [];
      });
      destinationFocus.requestFocus();
      return;
    }
    Navigator.pop(context, PlaceChoice(origin, place));
  }

  Future<void> pickOnMap() async {
    final place = await Navigator.of(context).push<RoutePlace>(
      MaterialPageRoute(
        builder: (_) => PickOnMapPage(
          planner: widget.planner,
          start: widget.near ?? (origin?.point),
          title: editing == 'origin' ? 'Punto de recogida' : 'Destino',
        ),
      ),
    );
    if (place != null && mounted) choose(place);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text(
        'Planea tu viaje',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: electric,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 46,
                    color: const Color(0xFFD5DCE8),
                  ),
                  Container(width: 10, height: 10, color: ink),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      key: const Key('origin-field'),
                      controller: originText,
                      focusNode: originFocus,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: widget.originLabel,
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.my_location_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('destination-field'),
                      controller: destinationText,
                      focusNode: destinationFocus,
                      autofocus: true,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: '¿A dónde vas?',
                        isDense: true,
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: mist,
                  child: Icon(Icons.pin_drop_outlined, color: electric),
                ),
                title: Text(
                  editing == 'origin'
                      ? 'Marcar recogida en el mapa'
                      : 'Marcar destino en el mapa',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: pickOnMap,
              ),
              if (editing == 'origin' && origin != null)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: mist,
                    child: Icon(Icons.gps_fixed_rounded, color: electric),
                  ),
                  title: const Text('Usar mi ubicación actual'),
                  onTap: () {
                    setState(() {
                      origin = null;
                      originText.clear();
                    });
                    destinationFocus.requestFocus();
                  },
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error!, style: const TextStyle(color: muted)),
                ),
              ...(results.isEmpty ? frequentPlaces : results).map(
                (p) => ListTile(
                  leading: Icon(
                    frequentPlaces.contains(p)
                        ? Icons.star_border_rounded
                        : Icons.place_outlined,
                    color: muted,
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    p.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => choose(p),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Mueve el mapa bajo el pin central y confirma el punto (como en Uber).
class PickOnMapPage extends StatefulWidget {
  final RoutePlanner? planner;
  final Coordinates? start;
  final String title;
  const PickOnMapPage({
    super.key,
    this.planner,
    this.start,
    required this.title,
  });
  @override
  State<PickOnMapPage> createState() => _PickOnMapPageState();
}

class _PickOnMapPageState extends State<PickOnMapPage> {
  late LatLng center = widget.start == null
      ? fusagasuga
      : latLng(widget.start!);
  String? name;
  bool resolving = false;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    resolve();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  void moved(LatLng point) {
    center = point;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 700), resolve);
  }

  Future<void> resolve() async {
    final planner = widget.planner;
    if (planner == null) return;
    setState(() => resolving = true);
    try {
      final found = await planner.reverse(
        Coordinates(center.latitude, center.longitude),
      );
      if (mounted) setState(() => name = found);
    } catch (_) {
      if (mounted) setState(() => name = null);
    } finally {
      if (mounted) setState(() => resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Stack(
      children: [
        RideMap(focus: center, onCenterChanged: moved),
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: Icon(Icons.location_on_rounded, size: 48, color: ink),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.white,
            elevation: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      resolving
                          ? 'Buscando dirección…'
                          : (name ?? 'Punto marcado en el mapa'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mueve el mapa para ajustar el punto.',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        RoutePlace(
                          name ?? 'Punto en el mapa',
                          '${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)}',
                          Coordinates(center.latitude, center.longitude),
                        ),
                      ),
                      child: const Text('Confirmar punto'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
