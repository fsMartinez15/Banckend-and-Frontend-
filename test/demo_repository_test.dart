import 'package:flutter_test/flutter_test.dart';
import 'package:ridemove/data/demo_repository.dart';
import 'package:ridemove/domain/fare.dart';
import 'package:ridemove/domain/ride_repository.dart';

void main() {
  test('Tarifa: banderazo + km + minutos, redondeada y con mínima', () {
    expect(Tariff.standard.estimate(500, 60), 600000);
    expect(Tariff.standard.estimate(5000, 900), 1280000);
    expect(formatCop(1280000), '\$ 12.800');
    expect(formatCop(150000000), '\$ 1.500.000');
  });

  test(
    'El conductor simulado acepta, llega, inicia y termina el viaje',
    () async {
      var now = DateTime(2026, 10, 29, 8);
      final repo = DemoRepository(autopilot: true, clock: () => now);
      await repo.signIn('passenger', '');
      await repo.command('request_trip', {
        'p_origin': 'Centro comercial Manila',
        'p_destination': 'Plaza Mayor',
        'p_origin_lat': DemoRepository.manila.latitude,
        'p_origin_lng': DemoRepository.manila.longitude,
        'p_destination_lat': DemoRepository.plazaMayor.latitude,
        'p_destination_lng': DemoRepository.plazaMayor.longitude,
        'p_distance_m': 1400,
        'p_duration_s': 300,
        'p_payment_method': 'wompi',
      });
      Future<JsonRow> trip() async => (await repo.trips()).firstWhere(
        (t) => t['origin'] == 'Centro comercial Manila',
      );
      expect((await trip())['status'], 'pending');
      expect((await trip()).fareCents, Tariff.standard.estimate(1400, 300));
      now = now.add(const Duration(seconds: 7));
      expect((await trip())['status'], 'accepted');
      expect((await trip())['driver_id'], 'driver');
      expect(await repo.locations(), isNotEmpty);
      now = now.add(const Duration(seconds: 25));
      expect((await trip())['status'], 'arrived');
      now = now.add(const Duration(seconds: 9));
      expect((await trip())['status'], 'in_progress');
      now = now.add(const Duration(seconds: 31));
      expect((await trip())['status'], 'completed');
      await repo.command('rate_trip', {
        'p_id': (await trip())['id'],
        'p_rating': 4,
        'p_comment': '',
      });
      expect(
        (await repo.users()).firstWhere(
          (u) => u['id'] == 'driver',
        )['rating_count'],
        129,
      );
      expect(
        await repo.checkoutUrl('${(await trip())['id']}'),
        startsWith('demo:'),
      );
      expect((await repo.payments()).single['status'], 'APPROVED');
    },
  );

  test(
    'El conductor libera un viaje aceptado y vuelve a la cola sin él',
    () async {
      final repo = DemoRepository();
      await repo.signIn('driver', '');
      await expectLater(
        repo.command('transition_trip', {'p_id': '1', 'p_status': 'accepted'}),
        throwsA(isA<AppFailure>()),
      );
      await repo.command('set_availability', {'p_available': true});
      await repo.command('transition_trip', {
        'p_id': '1',
        'p_status': 'accepted',
      });
      await repo.command('transition_trip', {
        'p_id': '1',
        'p_status': 'pending',
      });
      expect(repo.rides.first['status'], 'pending');
      expect(repo.rides.first['driver_id'], isNull);
      expect((await repo.trips()).where((t) => t['id'] == '1'), isEmpty);
    },
  );

  test('El pasajero no puede cancelar un viaje iniciado', () async {
    final repo = DemoRepository();
    await repo.signIn('passenger', '');
    await repo.command('request_trip', {
      'p_origin': 'Terminal',
      'p_destination': 'Plaza Mayor',
    });
    final id = (await repo.trips()).first['id'];
    repo.rides.firstWhere((r) => r['id'] == id)['status'] = 'in_progress';
    await expectLater(
      repo.command('transition_trip', {'p_id': id, 'p_status': 'cancelled'}),
      throwsA(isA<AppFailure>()),
    );
  });
}
