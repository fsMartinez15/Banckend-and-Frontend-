import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ridemove/data/open_route_adapter.dart';
import 'package:ridemove/domain/ride_repository.dart';

void main() {
  test(
    'Geocoder resolves the local landmark, deduplicates and caches',
    () async {
      var calls = 0;
      final feature = {
        'properties': {
          'osm_type': 'W',
          'osm_id': 1,
          'name': 'Plaza Mayor',
          'city': 'Fusagasugá',
        },
        'geometry': {
          'coordinates': [-74.3619659, 4.3439103],
        },
      };
      final planner = OpenRouteAdapter(
        requestInterval: Duration.zero,
        client: MockClient((request) async {
          calls++;
          expect(request.url.queryParameters['q'], 'Plaza Mayor, Fusagasugá');
          return http.Response(
            jsonEncode({
              'features': [feature, feature],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final places = await planner.search('Parque principal');
      expect(places.length, 1);
      expect(places.single.point.latitude, 4.3439103);
      expect(places.single.point.longitude, -74.3619659);
      await planner.search('Parque principal');
      expect(calls, 1);
    },
  );

  test(
    'Driving route keeps road geometry, distance and Spanish instructions',
    () async {
      final planner = OpenRouteAdapter(
        requestInterval: Duration.zero,
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/route/v1/driving/-74.370000,4.330000;-74.360000,4.340000',
          );
          expect(request.url.queryParameters['geometries'], 'geojson');
          expect(request.url.queryParameters['steps'], 'true');
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 1250,
                  'duration': 300,
                  'geometry': {
                    'coordinates': [
                      [-74.37, 4.33],
                      [-74.365, 4.338],
                      [-74.36, 4.34],
                    ],
                  },
                  'legs': [
                    {
                      'steps': [
                        {
                          'name': 'Calle 9',
                          'distance': 250,
                          'maneuver': {'type': 'turn', 'modifier': 'right'},
                        },
                        {
                          'name': '',
                          'distance': 0,
                          'maneuver': {'type': 'arrive'},
                        },
                      ],
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );
      final route = await planner.route(
        const Coordinates(4.33, -74.37),
        const Coordinates(4.34, -74.36),
      );
      expect(route.points.length, 3);
      expect(route.points[1].latitude, 4.338);
      expect(route.meters, 1250);
      expect(route.seconds, 300);
      expect(route.steps.first.instruction, 'Gira a la derecha por Calle 9');
      expect(route.steps.last.instruction, 'Llega al destino');
    },
  );

  test('NoRoute never falls back to a straight line', () async {
    final planner = OpenRouteAdapter(
      client: MockClient(
        (_) async => http.Response('{"code":"NoRoute","routes":[]}', 200),
      ),
    );
    await expectLater(
      planner.route(const Coordinates(4, -74), const Coordinates(5, -75)),
      throwsA(isA<AppFailure>()),
    );
  });

  test(
    'A failed request does not poison the serialized request queue',
    () async {
      var calls = 0;
      final planner = OpenRouteAdapter(
        requestInterval: Duration.zero,
        client: MockClient((_) async {
          if (calls++ == 0) return http.Response('Busy', 429);
          return http.Response('{"features":[]}', 200);
        }),
      );
      await expectLater(planner.search('Centro'), throwsA(isA<AppFailure>()));
      expect(await planner.search('Centro'), isEmpty);
    },
  );

  test('Reverse geocoding names the street and caches the point', () async {
    var calls = 0;
    final planner = OpenRouteAdapter(
      requestInterval: Duration.zero,
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/reverse');
        return http.Response(
          jsonEncode({
            'features': [
              {
                'properties': {
                  'street': 'Calle 8',
                  'housenumber': '5-20',
                  'district': 'Centro',
                },
              },
            ],
          }),
          200,
        );
      }),
    );
    expect(
      await planner.reverse(const Coordinates(4.34, -74.36)),
      'Calle 8 # 5-20, Centro',
    );
    await planner.reverse(const Coordinates(4.34, -74.36));
    expect(calls, 1);
  });
}
