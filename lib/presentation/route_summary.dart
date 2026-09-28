import 'package:flutter/material.dart';
import '../domain/route_planner.dart';
import 'ride_theme.dart';

String routeDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';
String routeDuration(double seconds) {
  final minutes = (seconds / 60).ceil();
  return minutes < 60
      ? '${minutes < 1 ? 1 : minutes} min'
      : '${minutes ~/ 60} h ${minutes % 60} min';
}

class RouteSummary extends StatelessWidget {
  final RoadRoute? route;
  final bool loading;
  final String? error, selecting;
  final String origin, destination;
  final VoidCallback retry, selectOrigin, selectDestination, cancelSelection;
  const RouteSummary({
    super.key,
    this.route,
    required this.loading,
    this.error,
    this.selecting,
    required this.origin,
    required this.destination,
    required this.retry,
    required this.selectOrigin,
    required this.selectDestination,
    required this.cancelSelection,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (loading)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Calculando ruta por las calles…')),
            ],
          ),
        ),
      if (selecting != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mist,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Toca el mapa para marcar ${selecting == 'origin' ? 'el origen' : 'el destino'}.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: cancelSelection,
                child: const Text('Cancelar selección'),
              ),
            ],
          ),
        ),
      if (error != null && !loading) ...[
        Text(error!, style: const TextStyle(color: muted, fontSize: 12)),
        TextButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reintentar ruta'),
        ),
      ],
      if (route != null) ...[
        Wrap(
          spacing: 18,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              routeDuration(route!.seconds),
              style: const TextStyle(
                color: electric,
                fontWeight: FontWeight.w900,
                fontSize: 28,
              ),
            ),
            Text(
              routeDistance(route!.meters),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
        const Text(
          'Recorrido calculado · estimación sin tráfico en tiempo real',
          style: TextStyle(color: muted, fontSize: 10),
        ),
        const SizedBox(height: 10),
      ],
      pointButton('A', origin, selectOrigin, electric),
      pointButton('B', destination, selectDestination, orange),
      if (route != null)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => SafeArea(
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .65,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                    children: [
                      const Text(
                        'Indicaciones del recorrido',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...route!.steps.map(
                        (step) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.turn_right_rounded,
                            color: electric,
                          ),
                          title: Text(step.instruction),
                          subtitle: Text(routeDistance(step.meters)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.alt_route_rounded),
            label: const Text('Ver indicaciones'),
          ),
        ),
    ],
  );

  Widget pointButton(
    String letter,
    String text,
    VoidCallback tap,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: color,
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 12,
              color: ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        IconButton(
          tooltip: letter == 'A'
              ? 'Marcar origen en el mapa'
              : 'Marcar destino en el mapa',
          onPressed: loading ? null : tap,
          icon: const Icon(
            Icons.edit_location_alt_outlined,
            size: 21,
            color: electric,
          ),
        ),
      ],
    ),
  );
}
