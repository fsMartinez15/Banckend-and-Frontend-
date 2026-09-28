import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridemove/application/location_tracker.dart';
import 'package:ridemove/data/demo_repository.dart';
import 'package:ridemove/domain/ride_repository.dart';

class FakeGps implements LocationDevice {
  final points = StreamController<Coordinates>.broadcast();
  @override
  Future<void> requestPermission() async {}
  @override
  Future<Coordinates> current() async => const Coordinates(4.34, -74.36);
  @override
  Stream<Coordinates> watch() => points.stream;
}

void main() {
  test(
    'foreground tracker publishes then stops on lifecycle request',
    () async {
      final repo = DemoRepository();
      await repo.signIn('driver', '');
      await repo.command('transition_trip', {
        'p_id': '1',
        'p_status': 'accepted',
      });
      final gps = FakeGps();
      final tracker = LocationTracker(gps, repo);
      await tracker.start(onError: (_) => fail('unexpected GPS failure'));
      expect((await repo.locations()).single['latitude'], 4.34);
      expect(tracker.lastPosition!.latitude, 4.34);
      gps.points.add(const Coordinates(4.35, -74.37));
      await Future<void>.delayed(Duration.zero);
      expect((await repo.locations()).single['latitude'], 4.35);
      expect(tracker.lastPosition!.latitude, 4.35);
      await tracker.stop();
      gps.points.add(const Coordinates(4.36, -74.38));
      await Future<void>.delayed(Duration.zero);
      expect((await repo.locations()).single['latitude'], 4.35);
      await gps.points.close();
    },
  );
}
