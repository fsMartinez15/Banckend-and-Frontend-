import 'package:geolocator/geolocator.dart';
import '../domain/ride_repository.dart';

class GeolocatorAdapter implements LocationDevice {
  @override
  Future<void> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppFailure('Activa el GPS del dispositivo.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const AppFailure(
        'Habilita el permiso de ubicación desde los ajustes.',
      );
    }
  }

  @override
  Future<Coordinates> current() async {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return Coordinates(p.latitude, p.longitude);
  }

  @override
  Stream<Coordinates> watch() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    ),
  ).map((p) => Coordinates(p.latitude, p.longitude));
}
