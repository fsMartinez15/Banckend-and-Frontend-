import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridemove/main.dart';
import 'package:ridemove/data/demo_repository.dart';
import 'package:ridemove/domain/external_navigation.dart';
import 'package:ridemove/presentation/trip_navigation_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ridemove/domain/ride_repository.dart';
import 'package:ridemove/domain/route_planner.dart';

class RecordingNavigation implements ExternalNavigation {
  String? destination;
  @override
  Future<bool> navigateTo(String destination) async {
    this.destination = destination;
    return true;
  }
}

class ExampleRoutePlanner implements RoutePlanner {
  @override
  Future<List<RoutePlace>> search(String address) async => [
    RoutePlace(
      address,
      address,
      address.contains('Universidad')
          ? const Coordinates(4.33598, -74.37123)
          : const Coordinates(4.34391, -74.36196),
    ),
  ];
  @override
  Future<RoadRoute> route(Coordinates origin, Coordinates destination) async =>
      RoadRoute(
        points: [origin, const Coordinates(4.34, -74.365), destination],
        meters: 1250,
        seconds: 300,
        steps: const [
          RouteStep('Gira a la derecha por Calle 9', 250),
          RouteStep('Llega al destino', 0),
        ],
      );
}

void main() {
  testWidgets(
    'Starting a trip opens world map navigation and preserves completion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = DemoRepository();
      final navigation = RecordingNavigation();
      await repo.signIn('driver', '');
      await repo.command('transition_trip', {
        'p_id': '1',
        'p_status': 'accepted',
      });
      await tester.pumpWidget(
        RideMoveApp(
          repository: repo,
          navigation: navigation,
          routePlanner: ExampleRoutePlanner(),
        ),
      );
      await tester.pumpAndSettle();
      // Drag below the interactive map so the dashboard, not the map, scrolls.
      await tester.dragFrom(const Offset(195, 690), const Offset(0, -520));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Iniciar viaje'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar viaje'));
      await tester.pumpAndSettle();
      expect(find.byType(TripNavigationScreen), findsOneWidget);
      expect((await repo.trips()).single['status'], 'in_progress');
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('1.3 km'), findsOneWidget);
      final line = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(line.polylines.single.points.length, 3);
      await tester.tap(find.text('Ver indicaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Gira a la derecha por Calle 9'), findsOneWidget);
      Navigator.of(
        tester.element(find.text('Indicaciones del recorrido')),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ver el mundo'));
      await tester.pumpAndSettle();
      final map = tester.widget<FlutterMap>(
        find.descendant(
          of: find.byType(TripNavigationScreen),
          matching: find.byType(FlutterMap),
        ),
      );
      expect(map.mapController!.camera.zoom, 2);
      await tester.ensureVisible(find.text('Navegar con Waze'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Navegar con Waze'));
      expect(navigation.destination, 'Parque principal');
      await tester.ensureVisible(find.text('Finalizar viaje').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalizar viaje').last);
      await tester.pumpAndSettle();
      expect(find.byType(TripNavigationScreen), findsNothing);
      expect((await repo.trips()).single['status'], 'completed');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Map destination shortcut validates and submits a trip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = DemoRepository();
    await repo.signIn('passenger', '');
    await repo.command('transition_trip', {
      'p_id': '1',
      'p_status': 'cancelled',
    });
    await tester.pumpWidget(RideMoveApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Centrar en Fusagasugá'), findsOneWidget);
    await tester.tap(find.byTooltip('Acercar mapa'));
    await tester.tap(find.byTooltip('Centrar en Fusagasugá'));
    await tester.drag(find.text('¿A dónde vamos hoy?'), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminal'));
    await tester.pumpAndSettle();
    expect(find.text('Terminal de transporte'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Terminal de transporte',
    );
    await tester.tap(find.text('Confirmar solicitud'));
    await tester.pumpAndSettle();
    expect(find.text('Elige un destino distinto al origen.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Parque principal',
    );
    await tester.tap(find.byTooltip('Intercambiar origen y destino'));
    await tester.tap(find.text('Confirmar solicitud'));
    await tester.pumpAndSettle();
    final trip = (await repo.trips()).firstWhere(
      (t) => t['status'] == 'pending',
    );
    expect(trip['origin'], 'Terminal de transporte');
    expect(trip['destination'], 'Parque principal');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Map home and request sheet support large text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = DemoRepository();
    await repo.signIn('passenger', '');
    await tester.pumpWidget(RideMoveApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solicitar viaje'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar solicitud'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Passenger can open dashboard on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RideMoveApp(repository: DemoRepository()));
    await tester.tap(find.text('Entrar como pasajero'));
    await tester.pumpAndSettle();
    expect(find.text('¿A dónde vamos hoy?'), findsOneWidget);
    expect(find.text('Solicitar viaje'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('Complete trip across roles and rate exactly once', () async {
    final repo = DemoRepository();
    await repo.signIn('driver', '');
    await repo.command('transition_trip', {
      'p_id': '1',
      'p_status': 'accepted',
    });
    await expectLater(
      repo.command('transition_trip', {'p_id': '1', 'p_status': 'completed'}),
      throwsStateError,
    );
    await repo.command('transition_trip', {
      'p_id': '1',
      'p_status': 'in_progress',
    });
    await repo.command('transition_trip', {
      'p_id': '1',
      'p_status': 'completed',
    });
    await repo.signOut();
    await repo.signIn('passenger', '');
    await repo.command('rate_trip', {
      'p_id': '1',
      'p_rating': 5,
      'p_comment': 'Muy bien',
    });
    expect((await repo.trips()).single['rating'], 5);
    await expectLater(
      repo.command('rate_trip', {'p_id': '1', 'p_rating': 1, 'p_comment': ''}),
      throwsStateError,
    );
  });
  for (final role in ['conductor', 'administrador']) {
    testWidgets('$role dashboard and profile fit a narrow phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(RideMoveApp(repository: DemoRepository()));
      final login = find.text('Entrar como $role');
      await tester.scrollUntilVisible(login, 250);
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mi perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Editar información'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  test(
    'Duplicate active requests are rejected and cancelled trips allow new requests',
    () async {
      final repo = DemoRepository();
      await repo.signIn('passenger', '');
      await expectLater(
        repo.command('create_trip', {
          'p_origin': 'Centro',
          'p_destination': 'Terminal',
        }),
        throwsStateError,
      );
      await repo.command('transition_trip', {
        'p_id': '1',
        'p_status': 'cancelled',
      });
      await repo.command('create_trip', {
        'p_origin': 'Centro',
        'p_destination': 'Terminal',
      });
      expect(
        (await repo.trips()).where((r) => r['status'] == 'pending').length,
        1,
      );
    },
  );
}
