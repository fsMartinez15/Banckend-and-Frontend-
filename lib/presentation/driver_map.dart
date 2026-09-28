import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'city_map.dart';

class DriverMap extends StatelessWidget {
  final double latitude, longitude;
  const DriverMap({super.key, required this.latitude, required this.longitude});
  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return SizedBox(
      height: 230,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CityMap(driver: point),
      ),
    );
  }
}
