import 'package:flutter/material.dart';
import '../domain/fare.dart';
import '../domain/ride_repository.dart';
import 'ride_theme.dart';

/// Panel inferior blanco con esquinas redondeadas (estilo app de movilidad).
class BottomPanel extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const BottomPanel({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 20),
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 16,
    shadowColor: ink.withValues(alpha: .3),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9DFEA),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// Ondas animadas mientras se busca conductor.
class PulseRadar extends StatefulWidget {
  final double size;
  const PulseRadar({super.key, this.size = 92});
  @override
  State<PulseRadar> createState() => _PulseRadarState();
}

class _PulseRadarState extends State<PulseRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: AnimatedBuilder(
      animation: c,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          for (final shift in [0.0, .5])
            Builder(
              builder: (_) {
                final t = (c.value + shift) % 1;
                return Container(
                  width: widget.size * (.35 + .65 * t),
                  height: widget.size * (.35 + .65 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: electric.withValues(alpha: .28 * (1 - t)),
                  ),
                );
              },
            ),
          Container(
            width: widget.size * .38,
            height: widget.size * .38,
            decoration: const BoxDecoration(
              color: electric,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Origen y destino con la línea vertical del recorrido.
class RouteStops extends StatelessWidget {
  final String origin, destination;
  final bool dense;
  const RouteStops({
    super.key,
    required this.origin,
    required this.destination,
    this.dense = false,
  });
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: dense ? 13 : 14,
      color: ink,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
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
                height: dense ? 22 : 28,
                color: const Color(0xFFD5DCE8),
              ),
              Container(width: 10, height: 10, color: ink),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
              SizedBox(height: dense ? 14 : 20),
              Text(
                destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta del conductor: nombre, calificación, vehículo, placa y llamada.
class DriverCard extends StatelessWidget {
  final JsonRow? driver, vehicle;
  final VoidCallback? onCall;
  final String? subtitle;
  const DriverCard({
    super.key,
    this.driver,
    this.vehicle,
    this.onCall,
    this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    final name = '${driver?['name'] ?? 'Tu conductor'}';
    final rating = (driver?['rating_avg'] as num?)?.toDouble();
    return Row(
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: mist,
          child: Text(
            name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (rating != null) '★ ${rating.toStringAsFixed(1)}',
                  if (vehicle != null)
                    '${vehicle!['brand']} · ${vehicle!['color']}',
                  ?subtitle,
                ].join('  ·  '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 13),
              ),
            ],
          ),
        ),
        if (vehicle != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD84D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ink, width: 1.6),
            ),
            child: Text(
              '${vehicle!['plate']}'.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: ink,
              ),
            ),
          ),
        if (onCall != null) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Llamar',
            onPressed: onCall,
            icon: const Icon(Icons.call_rounded),
          ),
        ],
      ],
    );
  }
}

/// Selector de medio de pago.
class PaymentSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const PaymentSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (key, icon) in [
        ('cash', Icons.payments_outlined),
        ('wompi', Icons.credit_card_rounded),
      ]) ...[
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onChanged(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: value == key ? mist : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: value == key ? electric : const Color(0xFFE1E6F0),
                  width: value == key ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: value == key ? electric : muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      key == 'cash' ? 'Efectivo' : 'Tarjeta · Nequi · PSE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: value == key ? ink : muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (key == 'cash') const SizedBox(width: 10),
      ],
    ],
  );
}

/// Estrellas seleccionables.
class StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const StarRating({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      5,
      (i) => IconButton(
        tooltip: '${i + 1} estrellas',
        iconSize: 38,
        onPressed: () => onChanged(i + 1),
        icon: Icon(
          i < value ? Icons.star_rounded : Icons.star_outline_rounded,
          color: i < value ? const Color(0xFFFFB31A) : const Color(0xFFC9D1DE),
        ),
      ),
    ),
  );
}

/// Etiqueta de estado del viaje.
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'completed' => (const Color(0xFFE6F7EF), const Color(0xFF1C7A55)),
      'cancelled' => (const Color(0xFFF1F3F6), muted),
      'pending' => (const Color(0xFFFFF4E2), const Color(0xFFA2661B)),
      _ => (mist, electric),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabels[status] ?? status,
        style: TextStyle(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Tarjeta de historial de un viaje.
class TripHistoryCard extends StatelessWidget {
  final JsonRow trip;
  final bool paid;
  final List<Widget> actions;
  final String? counterpart;
  const TripHistoryCard({
    super.key,
    required this.trip,
    this.paid = false,
    this.actions = const [],
    this.counterpart,
  });
  @override
  Widget build(BuildContext context) {
    final fare = trip.fareCents;
    final date = DateTime.tryParse('${trip['created_at']}')?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusPill(trip.tripStatus),
              if (fare != null)
                Text(
                  formatCop(fare),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          RouteStops(
            origin: '${trip['origin']}',
            destination: '${trip['destination']}',
            dense: true,
          ),
          const SizedBox(height: 12),
          Text(
            [
              if (date != null)
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
              if (trip.distanceMeters != null)
                distanceLabel(trip.distanceMeters!),
              paymentLabels[trip.paymentMethod] ?? trip.paymentMethod,
              if (paid) 'Pagado ✓',
              if (trip['rating'] != null) '★ ${trip['rating']}',
              ?counterpart,
            ].join('  ·  '),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}
