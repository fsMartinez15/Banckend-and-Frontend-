import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridemove/application/location_tracker.dart';
import 'package:ridemove/data/demo_repository.dart';
import 'package:ridemove/domain/external_navigation.dart';
import 'package:ridemove/domain/ride_repository.dart';
import 'package:ridemove/domain/route_planner.dart';
import 'package:ridemove/main.dart';

class FakeGps implements LocationDevice {
  final Coordinates point;
  FakeGps([this.point = DemoRepository.manila]);
  @override
  Future<void> requestPermission() async {}
  @override
  Future<Coordinates> current() async => point;
  @override
  Stream<Coordinates> watch() => const Stream.empty();
}

class RecordingNavigation implements ExternalNavigation {
  final calls = <String>[];
  @override
  Future<bool> navigateTo(String destination) async {
    calls.add('to:$destination');
    return true;
  }

  @override
  Future<bool> navigateToPoint(Coordinates point) async {
    calls.add('point:${point.latitude}');
    return true;
  }

  @override
  Future<bool> call(String phone) async {
    calls.add('call:$phone');
    return true;
  }

  @override
  Future<bool> openUrl(String url) async {
    calls.add('url:$url');
    return true;
  }
}

class ExampleRoutePlanner implements RoutePlanner {
  @override
  Future<List<RoutePlace>> search(String address) async => [
    RoutePlace('Terminal de transporte', 'Fusagasugá', DemoRepository.terminal),
  ];
  @override
  Future<RoadRoute> route(Coordinates origin, Coordinates destination) async =>
      RoadRoute(
        points: [origin, const Coordinates(4.341, -74.363), destination],
        meters: 2400,
        seconds: 420,
        steps: const [RouteStep('Gira a la derecha por Calle 9', 250)],
      );
  @override
  Future<String?> reverse(Coordinates point) async => 'Calle 8 # 5-20';
}

/// Repositorio de demostración que se comporta como cuenta real (muestra el registro).
class RealLikeRepository extends DemoRepository {
  String? registeredDocument;
  @override
  bool get demo => false;
  @override
  Future<bool> signUp(
    String email,
    String password,
    String name,
    String role, {
    String document = '',
  }) async {
    registeredDocument = document;
    return false;
  }
}

void phone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> enterAs(WidgetTester tester, String role) async {
  final button = find.text('Entrar como $role');
  await tester.scrollUntilVisible(
    button,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
}

Future<void> settle(WidgetTester tester, [int seconds = 1]) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Widget app(RideRepository repo, {RecordingNavigation? navigation}) =>
    RideMoveApp(
      repository: repo,
      tracker: LocationTracker(FakeGps(), repo),
      navigation: navigation ?? RecordingNavigation(),
      routePlanner: ExampleRoutePlanner(),
    );

void main() {
  testWidgets(
    'Pasajero: pide, ve llegar al conductor, viaja, califica y paga',
    (tester) async {
      phone(tester);
      var now = DateTime(2026, 10, 29, 8);
      final repo = DemoRepository(autopilot: true, clock: () => now);
      await tester.pumpWidget(app(repo));
      await enterAs(tester, 'pasajero');
      await settle(tester);
      expect(find.text('¿A dónde vas?'), findsOneWidget);
      expect(find.textContaining('conductores cerca'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Plaza Mayor'));
      await settle(tester);
      expect(find.textContaining('Solicitar RideMove · \$'), findsOneWidget);
      await tester.tap(find.text('Tarjeta · Nequi · PSE'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('request-ride')));
      await settle(tester);
      expect(find.text('Buscando conductor'), findsOneWidget);
      expect((await repo.trips()).first['payment_method'], 'wompi');

      now = now.add(const Duration(seconds: 7));
      await settle(tester, 4);
      expect(find.textContaining('Llega en'), findsOneWidget);
      expect(find.text('FUS 204'), findsOneWidget);
      expect(find.text('Fabián Martínez'), findsOneWidget);

      now = now.add(const Duration(seconds: 26));
      await settle(tester, 4);
      expect(find.text('Tu conductor llegó'), findsOneWidget);

      now = now.add(const Duration(seconds: 9));
      await settle(tester, 4);
      expect(find.text('En viaje a Plaza Mayor'), findsOneWidget);
      expect(find.text('Cancelar viaje'), findsNothing);

      now = now.add(const Duration(seconds: 31));
      await settle(tester, 4);
      expect(find.text('¡Llegaste a tu destino!'), findsOneWidget);
      await tester.tap(find.byTooltip('4 estrellas'));
      await tester.pump();
      await tester.ensureVisible(find.text('Enviar calificación'));
      await tester.tap(find.text('Enviar calificación'));
      await settle(tester);
      expect((await repo.trips()).first['rating'], 4);
      await tester.ensureVisible(find.textContaining('con Wompi'));
      await tester.tap(find.textContaining('con Wompi'));
      await settle(tester);
      expect((await repo.payments()).single['status'], 'APPROVED');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pasajero cancela mientras se busca conductor', (tester) async {
    phone(tester);
    final repo = DemoRepository();
    await tester.pumpWidget(app(repo));
    await enterAs(tester, 'pasajero');
    await settle(tester);
    await tester.tap(find.byKey(const Key('where-to')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('destination-field')),
      'Terminal',
    );
    await settle(tester, 2);
    await tester.tap(find.text('Terminal de transporte').first);
    await settle(tester);
    expect(find.text('Calle 8 # 5-20'), findsOneWidget);
    await tester.tap(find.byKey(const Key('request-ride')));
    await settle(tester);
    await tester.tap(find.text('Cancelar solicitud'));
    await settle(tester);
    await tester.tap(find.text('Cancelar viaje'));
    await settle(tester);
    expect((await repo.trips()).first['status'], 'cancelled');
    expect(find.text('¿A dónde vas?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Conductor: se conecta, acepta, llega, inicia, finaliza y cobra',
    (tester) async {
      phone(tester);
      final repo = DemoRepository();
      final navigation = RecordingNavigation();
      await tester.pumpWidget(app(repo, navigation: navigation));
      await enterAs(tester, 'conductor');
      await settle(tester);
      expect(find.text('Estás desconectado'), findsOneWidget);
      await tester.tap(find.byKey(const Key('go-online')));
      await settle(tester);
      expect(find.text('1 solicitud cerca'), findsOneWidget);
      expect(find.textContaining('\$ '), findsWidgets);

      await tester.tap(find.byKey(const Key('accept-1')));
      await settle(tester);
      expect(find.text('Recoge a Carlos'), findsOneWidget);
      expect(await repo.locations(), isNotEmpty);
      await tester.tap(find.text('Navegar'));
      await tester.pump();
      expect(navigation.calls.single, startsWith('point:'));

      await tester.tap(find.byKey(const Key('driver-arrived')));
      await settle(tester);
      expect(find.text('Esperando a Carlos'), findsOneWidget);
      await tester.tap(find.byKey(const Key('driver-in_progress')));
      await settle(tester);
      expect(find.text('Llevando a Carlos'), findsOneWidget);
      await tester.tap(find.byKey(const Key('driver-completed')));
      await settle(tester);
      expect(find.text('Viaje completado'), findsOneWidget);
      expect(find.text('Cobra en efectivo'), findsOneWidget);
      expect(
        (await repo.trips()).firstWhere((t) => t['id'] == '1')['status'],
        'completed',
      );
      await tester.tap(find.text('Listo, buscar otro viaje'));
      await settle(tester);
      expect(find.text('Buscando viajes…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('El registro pide la cédula al cliente', (tester) async {
    phone(tester);
    final repo = RealLikeRepository();
    await tester.pumpWidget(app(repo));
    await tester.scrollUntilVisible(
      find.text('Soy nuevo, crear cuenta'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Soy nuevo, crear cuenta'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre completo'),
      'Ana Pérez',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo electrónico'),
      'ana@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Contraseña'),
      'Segura123',
    );
    await tester.scrollUntilVisible(
      find.text('Crear cuenta'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();
    expect(find.textContaining('si vas a viajar, tu cédula'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Número de cédula'),
      '1.069.700.009',
    );
    await tester.tap(find.text('Crear cuenta'));
    await settle(tester);
    expect(repo.registeredDocument, '1069700009');
  });

  for (final role in ['pasajero', 'conductor', 'administrador']) {
    testWidgets('$role cabe en un teléfono angosto con texto grande', (
      tester,
    ) async {
      phone(tester, textScale: 1.3);
      final repo = DemoRepository(autopilot: true);
      await tester.pumpWidget(app(repo));
      await enterAs(tester, role);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Viajes'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cuenta'));
      await settle(tester);
      expect(find.text('Editar información'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
