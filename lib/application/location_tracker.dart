import 'dart:async';
import '../domain/ride_repository.dart';

/// Coordinates foreground tracking without depending on Flutter or a GPS SDK.
class LocationTracker {
  final LocationDevice device;
  final RideRepository repository;
  StreamSubscription<Coordinates>? _subscription;
  int _generation = 0;
  bool _sending = false;
  Coordinates? lastPosition;
  LocationTracker(this.device, this.repository);
  bool get isTracking => _subscription != null;
  Future<void> start({required void Function(String) onError}) async {
    await stop();
    final generation = _generation;
    await device.requestPermission();
    final first = await device.current();
    if (generation != _generation) {
      return;
    }
    await _send(first);
    if (generation != _generation) {
      return;
    }
    _subscription = device.watch().listen(
      (point) async {
        if (_sending || generation != _generation) {
          return;
        }
        _sending = true;
        try {
          await _send(point);
        } catch (_) {
          onError('No se pudo actualizar la ubicación. Revisa la conexión.');
        } finally {
          _sending = false;
        }
      },
      onError: (Object _) {
        onError('GPS interrumpido. Vuelve a activar tu ubicación.');
        stop();
      },
    );
  }

  Future<void> _send(Coordinates p) async {
    await repository.command('save_location', {
      'p_latitude': p.latitude,
      'p_longitude': p.longitude,
    });
    lastPosition = p;
  }

  Future<void> stop() async {
    _generation++;
    await _subscription?.cancel();
    _subscription = null;
  }
}
