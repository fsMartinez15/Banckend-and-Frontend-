import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'city_map.dart';
import 'ride_theme.dart';

class PassengerHome extends StatefulWidget {
  final String name;
  final LatLng? driver;
  final VoidCallback? onRequest;
  final ValueChanged<String> onDestination;
  final List<Widget> activeTrips;
  const PassengerHome({
    super.key,
    required this.name,
    this.driver,
    required this.onRequest,
    required this.onDestination,
    required this.activeTrips,
  });
  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  double extent = .46;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      // Give larger text a taller starting sheet; every item remains scrollable.
      final initial = MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? .60
          : .46;
      final currentExtent = extent == .46 ? initial : extent;
      return Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: bounds.maxHeight * currentExtent,
            child: CityMap(driver: widget.driver),
          ),
          Positioned(
            top: 14,
            left: 18,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1015233D), blurRadius: 20),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.driver == null
                            ? Icons.location_city_rounded
                            : Icons.directions_car_rounded,
                        color: electric,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.driver == null
                            ? 'Explora Fusagasugá'
                            : 'Ubicación del conductor',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              setState(() => extent = notification.extent);
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: initial,
              minChildSize: .25,
              maxChildSize: .88,
              snap: true,
              snapSizes: [initial],
              builder: (context, controller) => Container(
                decoration: const BoxDecoration(
                  color: canvas,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1515233D),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCD4E5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Hola, ${widget.name} 👋',
                        style: const TextStyle(
                          color: muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '¿A dónde vamos hoy?',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.9,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: widget.onRequest,
                        style: FilledButton.styleFrom(
                          backgroundColor: ink,
                          padding: const EdgeInsets.all(18),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search_rounded, color: orange),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Solicitar viaje',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, size: 21),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'TUS DESTINOS, MÁS CERCA',
                        style: TextStyle(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          destination(
                            Icons.park_outlined,
                            'Parque',
                            'Parque principal',
                            const Color(0xFFFFEDE3),
                          ),
                          const SizedBox(width: 10),
                          destination(
                            Icons.school_outlined,
                            'Universidad',
                            'Universidad de Cundinamarca',
                            mist,
                          ),
                          const SizedBox(width: 10),
                          destination(
                            Icons.directions_bus_outlined,
                            'Terminal',
                            'Terminal de transporte',
                            const Color(0xFFE6F4F2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const Row(
                        children: [
                          Icon(Icons.route_rounded, color: electric, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Tu viaje actual',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...widget.activeTrips,
                      const Text(
                        'Desliza la tarjeta para explorar el mapa o consultar tu viaje.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget destination(
    IconData icon,
    String label,
    String address,
    Color color,
  ) => Expanded(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onRequest == null
            ? null
            : () => widget.onDestination(address),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: ink, size: 23),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
