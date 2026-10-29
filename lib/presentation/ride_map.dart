import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/ride_repository.dart';
import 'ride_theme.dart';

/// Referencia de la ciudad cuando aún no hay GPS.
const fusagasuga = LatLng(4.3365, -74.3638);

LatLng latLng(Coordinates c) => LatLng(c.latitude, c.longitude);

enum PinKind { me, car, nearbyCar, pickup, dropoff, request }

class MapPin {
  final String id;
  final LatLng point;
  final PinKind kind;
  final String label;
  const MapPin(this.id, this.point, this.kind, this.label);
}

/// Mapa base de RideMove: tonos suaves, pines tipo app de movilidad, ruta,
/// encuadre automático y autos que se desplazan con animación.
class RideMap extends StatefulWidget {
  final List<MapPin> pins;
  final List<LatLng> route;
  final LatLng? focus;

  /// Cambia este valor para volver a encuadrar pines y ruta.
  final Object? fitKey;
  final EdgeInsets fitPadding;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<LatLng>? onCenterChanged;
  final VoidCallback? onLocate;
  final double bottomInset;
  const RideMap({
    super.key,
    this.pins = const [],
    this.route = const [],
    this.focus,
    this.fitKey,
    this.fitPadding = const EdgeInsets.fromLTRB(60, 120, 60, 80),
    this.onTap,
    this.onCenterChanged,
    this.onLocate,
    this.bottomInset = 0,
  });
  @override
  State<RideMap> createState() => RideMapState();
}

class RideMapState extends State<RideMap> with SingleTickerProviderStateMixin {
  final controller = MapController();
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  final _from = <String, LatLng>{}, _to = <String, LatLng>{};
  bool ready = false, failed = false;
  int retry = 0;

  @override
  void initState() {
    super.initState();
    for (final p in widget.pins) {
      _from[p.id] = _to[p.id] = p.point;
    }
  }

  @override
  void didUpdateWidget(RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    var moved = false;
    for (final p in widget.pins) {
      final target = _to[p.id];
      if (target == null) {
        _from[p.id] = _to[p.id] = p.point;
      } else if (target != p.point) {
        _from[p.id] = _current(p.id);
        _to[p.id] = p.point;
        moved = true;
      }
    }
    final ids = widget.pins.map((p) => p.id).toSet();
    _from.removeWhere((k, _) => !ids.contains(k));
    _to.removeWhere((k, _) => !ids.contains(k));
    if (moved) motion.forward(from: 0);
    if (ready && widget.fitKey != oldWidget.fitKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) => fit());
    }
  }

  LatLng _current(String id) {
    final a = _from[id], b = _to[id];
    if (a == null || b == null) return b ?? a ?? fusagasuga;
    final t = Curves.easeInOut.transform(motion.value);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Encuadra la ruta y los pines importantes (no los autos cercanos).
  void fit() {
    if (!mounted) return;
    final points = [
      ...widget.route,
      ...widget.pins
          .where((p) => p.kind != PinKind.nearbyCar)
          .map((p) => p.point),
    ];
    if (points.isEmpty) {
      controller.move(widget.focus ?? fusagasuga, 15);
      return;
    }
    if (points.length == 1) {
      controller.move(points.single, 16);
      return;
    }
    controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: widget.fitPadding.copyWith(
          bottom: widget.fitPadding.bottom + widget.bottomInset,
        ),
        maxZoom: 17,
      ),
    );
  }

  void moveTo(LatLng point, [double zoom = 16]) => controller.move(point, zoom);

  @override
  void dispose() {
    motion.dispose();
    controller.dispose();
    super.dispose();
  }

  void tileFailed() {
    if (failed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !failed) setState(() => failed = true);
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: widget.focus ?? fusagasuga,
          initialZoom: 15,
          minZoom: 4,
          maxZoom: 18,
          backgroundColor: const Color(0xFFEFF2F6),
          onMapReady: () {
            ready = true;
            fit();
          },
          onTap: (_, point) => widget.onTap?.call(point),
          onPositionChanged: (camera, gesture) =>
              widget.onCenterChanged?.call(camera.center),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            key: ValueKey(retry),
            urlTemplate: const String.fromEnvironment(
              'TILE_URL',
              defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            userAgentPackageName: 'co.ridemove.ridemove',
            errorTileCallback: (_, _, _) => tileFailed(),
            tileBuilder: (context, tile, _) => ColorFiltered(
              // Mapa desaturado y claro: la ruta y los autos resaltan.
              colorFilter: const ColorFilter.matrix([
                0.55, 0.38, 0.07, 0, 28, //
                0.30, 0.63, 0.07, 0, 30, //
                0.30, 0.38, 0.32, 0, 40, //
                0, 0, 0, 1, 0,
              ]),
              child: tile,
            ),
          ),
          if (widget.route.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.route,
                  strokeWidth: 7,
                  color: ink,
                  borderStrokeWidth: 2,
                  borderColor: Colors.white,
                ),
                Polyline(
                  points: widget.route,
                  strokeWidth: 3.5,
                  color: electric,
                ),
              ],
            ),
          AnimatedBuilder(
            animation: motion,
            builder: (context, _) => MarkerLayer(
              markers: [
                for (final p in widget.pins)
                  Marker(
                    point: _current(p.id),
                    width: _size(p.kind).width,
                    height: _size(p.kind).height,
                    alignment:
                        p.kind == PinKind.pickup ||
                            p.kind == PinKind.dropoff ||
                            p.kind == PinKind.request
                        ? Alignment.topCenter
                        : Alignment.center,
                    child: Semantics(label: p.label, child: _pin(p)),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  color: Colors.white.withValues(alpha: .8),
                  child: const Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 9, color: muted),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      if (widget.onLocate != null)
        Positioned(
          right: 14,
          bottom: widget.bottomInset + 14,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: ink.withValues(alpha: .25),
            child: IconButton(
              tooltip: 'Mi ubicación',
              onPressed: widget.onLocate,
              icon: const Icon(Icons.my_location_rounded, color: ink),
            ),
          ),
        ),
      if (failed)
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: SafeArea(
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 17, color: muted),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No se pudo cargar el mapa',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        failed = false;
                        retry++;
                      }),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );

  static Size _size(PinKind kind) => switch (kind) {
    PinKind.me => const Size(34, 34),
    PinKind.car => const Size(46, 46),
    PinKind.nearbyCar => const Size(30, 30),
    _ => const Size(40, 48),
  };

  Widget _pin(MapPin p) => switch (p.kind) {
    PinKind.me => Container(
      decoration: BoxDecoration(
        color: electric.withValues(alpha: .18),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: electric,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x40315BFF), blurRadius: 8)],
        ),
      ),
    ),
    PinKind.car || PinKind.nearbyCar => Container(
      decoration: BoxDecoration(
        color: p.kind == PinKind.car ? ink : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: p.kind == PinKind.car ? Colors.white : const Color(0xFFD5DCE8),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3315233D),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.directions_car_filled_rounded,
        size: p.kind == PinKind.car ? 24 : 16,
        color: p.kind == PinKind.car ? Colors.white : ink,
      ),
    ),
    _ => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: switch (p.kind) {
              PinKind.pickup => electric,
              PinKind.dropoff => ink,
              _ => orange,
            },
            shape: p.kind == PinKind.dropoff
                ? BoxShape.rectangle
                : BoxShape.circle,
            borderRadius: p.kind == PinKind.dropoff
                ? BorderRadius.circular(6)
                : null,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x4015233D), blurRadius: 8),
            ],
          ),
          child: Icon(
            switch (p.kind) {
              PinKind.pickup => Icons.person_pin_circle_rounded,
              PinKind.dropoff => Icons.flag_rounded,
              _ => Icons.hail_rounded,
            },
            size: 15,
            color: Colors.white,
          ),
        ),
        Container(width: 3, height: 14, color: ink),
      ],
    ),
  };
}
