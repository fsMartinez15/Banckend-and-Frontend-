import 'package:flutter/material.dart';
import 'ride_map.dart';
import 'ride_theme.dart';

class WelcomeMapHero extends StatelessWidget {
  const WelcomeMapHero({super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: Column(
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            children: [
              const IgnorePointer(child: RideMap()),
              Positioned(
                top: 16,
                left: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.place_rounded, color: orange, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'FUSAGASUGÁ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: 1.7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [ink, Color(0xFF263E70)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MENOS VUELTAS. MÁS PLANES.',
                style: TextStyle(
                  color: orange,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tu ciudad,\na un viaje de distancia.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -.9,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Elige tu destino. Nosotros conectamos el camino.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .75),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
