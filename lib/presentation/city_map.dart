import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ride_theme.dart';
import '../domain/route_planner.dart';

/// City reference, never presented as the passenger's GPS position.
const fusagasuga = LatLng(4.3365, -74.3638);

class CityMap extends StatefulWidget {
  final LatLng? driver;
  final bool controls;
  final RoadRoute? route;
  final LatLng? origin, destination;
  final ValueChanged<LatLng>? onPointSelected;
  const CityMap({
    super.key,
    this.driver,
    this.controls = true,
    this.route,
    this.origin,
    this.destination,
    this.onPointSelected,
  });
  @override
  State<CityMap> createState() => _CityMapState();
}

class _CityMapState extends State<CityMap> {
  final controller = MapController();
  bool failed = false;
  bool following = true;
  int retry = 0;
  @override
  void didUpdateWidget(CityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.route != null && widget.route != oldWidget.route) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fitRoute();
      });
    }
    if (following && oldWidget.driver != widget.driver) {
      controller.move(widget.driver ?? fusagasuga, controller.camera.zoom);
    }
  }

  void fitRoute() {
    final route = widget.route;
    if (route == null) return;
    following = false;
    controller.fitCamera(
      CameraFit.coordinates(
        coordinates: route.points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList(),
        padding: const EdgeInsets.fromLTRB(42, 40, 86, 46),
        maxZoom: 16,
      ),
    );
  }

  @override
  void dispose() {
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
          initialCenter: widget.driver ?? fusagasuga,
          initialZoom: widget.driver == null ? 14 : 15,
          minZoom: 2,
          maxZoom: 18,
          onMapReady: fitRoute,
          onTap: (_, point) => widget.onPointSelected?.call(point),
          backgroundColor: const Color(0xFFE9EEF4),
          onPositionChanged: (_, hasGesture) {
            if (hasGesture) following = false;
          },
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            key: ValueKey(retry),
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'co.ridemove.ridemove',
            errorTileCallback: (_, _, _) => tileFailed(),
          ),
          if (widget.route != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.route!.points
                      .map((p) => LatLng(p.latitude, p.longitude))
                      .toList(),
                  strokeWidth: 6,
                  color: electric,
                  borderStrokeWidth: 3,
                  borderColor: Colors.white,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (widget.origin != null)
                endpoint(widget.origin!, 'A', electric, 'Origen del viaje'),
              if (widget.destination != null)
                endpoint(widget.destination!, 'B', orange, 'Destino del viaje'),
              if (widget.driver != null ||
                  (widget.origin == null && widget.destination == null))
                Marker(
                  point: widget.driver ?? fusagasuga,
                  width: 64,
                  height: 64,
                  child: Semantics(
                    label: widget.driver == null
                        ? 'Centro de Fusagasugá'
                        : 'Última ubicación del conductor',
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: electric.withValues(alpha: .14),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.driver == null ? electric : ink,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26315BFF),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.driver == null
                              ? Icons.location_city_rounded
                              : Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Material(
              color: Colors.white.withValues(alpha: .94),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
              ),
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10, color: ink),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      if (widget.controls)
        Positioned(
          right: 16,
          bottom: 30,
          child: Column(
            children: [
              if (widget.route != null) ...[
                mapButton(Icons.route_rounded, 'Ver ruta completa', fitRoute),
                const SizedBox(height: 8),
              ],
              mapButton(Icons.public_rounded, 'Ver el mundo', () {
                following = false;
                controller.move(const LatLng(15, -30), 2);
              }),
              const SizedBox(height: 8),
              mapButton(
                Icons.add,
                'Acercar mapa',
                () => controller.move(
                  controller.camera.center,
                  (controller.camera.zoom + 1).clamp(2, 18),
                ),
              ),
              const SizedBox(height: 8),
              mapButton(
                Icons.remove,
                'Alejar mapa',
                () => controller.move(
                  controller.camera.center,
                  (controller.camera.zoom - 1).clamp(2, 18),
                ),
              ),
              const SizedBox(height: 12),
              mapButton(
                Icons.center_focus_strong_rounded,
                widget.driver == null
                    ? 'Centrar en Fusagasugá'
                    : 'Centrar en el conductor',
                () {
                  following = true;
                  controller.move(
                    widget.driver ?? fusagasuga,
                    widget.driver == null ? 14 : 15,
                  );
                },
              ),
            ],
          ),
        ),
      if (failed)
        Positioned(
          bottom: 28,
          left: 12,
          right: widget.controls ? 76 : 12,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 17, color: muted),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No se pudo cargar el mapa',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      failed = false;
                      retry++;
                    }),
                    child: const Text(
                      'Reintentar',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
  Marker endpoint(LatLng point, String letter, Color color, String label) =>
      Marker(
        point: point,
        width: 38,
        height: 38,
        child: Semantics(
          label: label,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x3015233D), blurRadius: 8),
              ],
            ),
            child: Text(
              letter,
              style: const TextStyle(
                color: ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
  Widget mapButton(IconData icon, String tooltip, VoidCallback action) =>
      Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: ink.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(15),
        child: IconButton(
          tooltip: tooltip,
          onPressed: action,
          icon: Icon(icon, color: ink),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      );
}
