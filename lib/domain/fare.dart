import 'dart:math' as math;
import 'ride_repository.dart';

/// Tarifa tipo Uber en centavos de COP: banderazo + km + minuto, con mínima.
class Tariff {
  final int baseCents, perKmCents, perMinCents, minimumCents;
  const Tariff({
    required this.baseCents,
    required this.perKmCents,
    required this.perMinCents,
    required this.minimumCents,
  });
  static const standard = Tariff(
    baseCents: 350000,
    perKmCents: 110000,
    perMinCents: 25000,
    minimumCents: 600000,
  );
  factory Tariff.fromJson(Map<String, dynamic> json) => Tariff(
    baseCents: (json['base_cents'] as num).toInt(),
    perKmCents: (json['per_km_cents'] as num).toInt(),
    perMinCents: (json['per_min_cents'] as num).toInt(),
    minimumCents: (json['minimum_cents'] as num).toInt(),
  );

  /// Igual a `public.fare_for` en la base de datos: redondeo a la centena de pesos.
  int estimate(num meters, num seconds) {
    final raw =
        baseCents +
        perKmCents * math.max(meters, 0) / 1000 +
        perMinCents * math.max(seconds, 0) / 60;
    final rounded = (raw / 10000).round() * 10000;
    return math.max(minimumCents, rounded);
  }
}

/// $ 12.800
String formatCop(int cents) {
  final pesos = (cents / 100).round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < pesos.length; i++) {
    if (i > 0 && (pesos.length - i) % 3 == 0) buffer.write('.');
    buffer.write(pesos[i]);
  }
  return '\$ $buffer';
}

/// Distancia en línea recta (metros).
double haversine(Coordinates a, Coordinates b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude),
      dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

/// Tiempo estimado en ciudad (24 km/h, factor de desvío 1,35), mínimo 1 minuto.
int etaMinutes(double straightMeters) =>
    math.max(1, (straightMeters * 1.35 / (24000 / 60)).ceil());

String distanceLabel(num meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

String durationLabel(num seconds) {
  final minutes = math.max(1, (seconds / 60).ceil());
  return minutes < 60
      ? '$minutes min'
      : '${minutes ~/ 60} h ${minutes % 60} min';
}
