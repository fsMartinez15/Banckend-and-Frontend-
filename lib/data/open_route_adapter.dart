import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../domain/ride_repository.dart';
import '../domain/route_planner.dart';

/// Public endpoints are for the academic pilot; production can use hosted instances.
class OpenRouteAdapter implements RoutePlanner {
  final http.Client client;
  final String geocoderUrl, routerUrl;
  final Duration requestInterval;
  final _places = <String, List<RoutePlace>>{};
  final _routes = <String, RoadRoute>{};
  Future<void> _queue = Future.value();
  DateTime? _lastRequest;
  OpenRouteAdapter({
    http.Client? client,
    this.geocoderUrl = 'https://photon.komoot.io',
    this.routerUrl = 'https://router.project-osrm.org',
    this.requestInterval = const Duration(milliseconds: 1100),
  }) : client = client ?? http.Client();

  Future<dynamic> _get(Uri uri) {
    final result = Completer<dynamic>();
    _queue = _queue.then((_) async {
      try {
        final last = _lastRequest;
        if (last != null) {
          final wait = requestInterval - DateTime.now().difference(last);
          if (wait > Duration.zero) await Future<void>.delayed(wait);
        }
        _lastRequest = DateTime.now();
        final response = await client
            .get(
              uri,
              // En navegador no se envía User-Agent: provoca un preflight CORS que OSRM rechaza.
              headers: {
                if (!kIsWeb)
                  'User-Agent': 'RideMove/1.0 (co.ridemove.ridemove)',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 18));
        if (response.statusCode == 429) {
          throw const AppFailure(
            'El servicio está ocupado. Espera un momento y vuelve a calcular.',
          );
        }
        if (response.statusCode != 200) {
          throw const AppFailure(
            'El servicio de rutas no está disponible. Intenta de nuevo.',
          );
        }
        result.complete(jsonDecode(utf8.decode(response.bodyBytes)));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  static String normalized(String value) {
    var result = value.trim().toLowerCase();
    for (final pair in {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
    }.entries) {
      result = result.replaceAll(pair.key, pair.value);
    }
    return result;
  }

  static String placeQuery(String address) =>
      normalized(address) == 'parque principal'
      ? 'Plaza Mayor'
      : address.trim();

  @override
  Future<List<RoutePlace>> search(String address) async {
    final query = placeQuery(address);
    final key = normalized(query);
    if (_places.containsKey(key)) return _places[key]!;
    final data = await _get(
      Uri.parse('$geocoderUrl/api/').replace(
        queryParameters: {
          'q': query.contains(',') || normalized(query).contains('fusagasuga')
              ? query
              : '$query, Fusagasugá',
          'lat': '4.3365',
          'lon': '-74.3638',
          'limit': '5',
        },
      ),
    );
    final seen = <String>{};
    final places = <RoutePlace>[];
    for (final feature in (data['features'] as List)) {
      final props = feature['properties'] as Map;
      final coords = feature['geometry']['coordinates'] as List;
      final id = '${props['osm_type']}:${props['osm_id']}';
      if (!seen.add(id)) continue;
      final point = _point(coords);
      final name = '${props['name'] ?? props['street'] ?? query}';
      final description = [
        name,
        props['street'],
        props['housenumber'],
        props['city'],
        props['state'],
        props['country'],
      ].where((e) => e != null && '$e'.isNotEmpty).toSet().join(', ');
      places.add(RoutePlace(name, description, point));
    }
    if (_places.length >= 100) _places.remove(_places.keys.first);
    final exact = places.where((p) => normalized(p.name) == key).toList();
    _places[key] = List.unmodifiable(exact.length == 1 ? exact : places);
    return _places[key]!;
  }

  static Coordinates _point(List value) {
    final lon = (value[0] as num).toDouble(),
        lat = (value[1] as num).toDouble();
    if (!lon.isFinite || !lat.isFinite || lon.abs() > 180 || lat.abs() > 90) {
      throw const AppFailure('El servicio devolvió una ubicación inválida.');
    }
    return Coordinates(lat, lon);
  }

  @override
  Future<RoadRoute> route(Coordinates origin, Coordinates destination) async {
    String pair(Coordinates p) =>
        '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}';
    final key = '${pair(origin)};${pair(destination)}';
    if (_routes.containsKey(key)) return _routes[key]!;
    final data = await _get(
      Uri.parse('$routerUrl/route/v1/driving/$key').replace(
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
          'radiuses': '500;500',
        },
      ),
    );
    if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
      throw const AppFailure(
        'No hay una ruta por carretera entre esos puntos. Ajusta los lugares en el mapa.',
      );
    }
    final row = data['routes'][0];
    final points = (row['geometry']['coordinates'] as List)
        .map((p) => _point(p as List))
        .toList();
    final meters = (row['distance'] as num).toDouble(),
        seconds = (row['duration'] as num).toDouble();
    if (points.length < 2 ||
        !meters.isFinite ||
        !seconds.isFinite ||
        meters < 1 ||
        seconds < 0) {
      throw const AppFailure(
        'No se recibió un recorrido válido. Elige dos puntos distintos.',
      );
    }
    final steps = <RouteStep>[];
    for (final leg in row['legs'] as List) {
      for (final step in leg['steps'] as List) {
        steps.add(
          RouteStep(
            instruction(step as Map),
            (step['distance'] as num).toDouble(),
          ),
        );
      }
    }
    final route = RoadRoute(
      points: List.unmodifiable(points),
      steps: List.unmodifiable(steps),
      meters: meters,
      seconds: seconds,
    );
    if (_routes.length >= 50) _routes.remove(_routes.keys.first);
    _routes[key] = route;
    return route;
  }

  final _names = <String, String?>{};

  @override
  Future<String?> reverse(Coordinates point) async {
    final key =
        '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';
    if (_names.containsKey(key)) return _names[key];
    final data = await _get(
      Uri.parse('$geocoderUrl/reverse').replace(
        queryParameters: {
          'lat': point.latitude.toStringAsFixed(6),
          'lon': point.longitude.toStringAsFixed(6),
          'limit': '1',
        },
      ),
    );
    final features = data['features'] as List? ?? const [];
    String? name;
    if (features.isNotEmpty) {
      final props = features.first['properties'] as Map;
      final street = props['street'], number = props['housenumber'];
      name = [
        if (props['name'] != null) props['name'],
        if (street != null) number == null ? street : '$street # $number',
        if (props['district'] != null) props['district'],
      ].map((e) => '$e').toSet().take(2).join(', ');
      if (name.isEmpty) name = null;
    }
    if (_names.length >= 200) _names.remove(_names.keys.first);
    _names[key] = name;
    return name;
  }

  static String instruction(Map step) {
    final maneuver = step['maneuver'] as Map;
    final type = maneuver['type'], modifier = maneuver['modifier'];
    final direction =
        const {
          'left': 'a la izquierda',
          'right': 'a la derecha',
          'slight left': 'ligeramente a la izquierda',
          'slight right': 'ligeramente a la derecha',
          'sharp left': 'cerrado a la izquierda',
          'sharp right': 'cerrado a la derecha',
          'straight': 'recto',
          'uturn': 'en U',
        }[modifier] ??
        'por la vía indicada';
    final road = '${step['name'] ?? ''}'.trim();
    final suffix = road.isEmpty ? '' : ' por $road';
    if (type == 'arrive') return 'Llega al destino';
    if (type == 'depart') return 'Inicia el recorrido$suffix';
    if (type == 'roundabout' || type == 'rotary') {
      return 'En la glorieta, toma ${maneuver['exit'] == null ? 'la salida indicada' : 'la salida ${maneuver['exit']}'}$suffix';
    }
    if (type == 'merge') return 'Incorpórate $direction$suffix';
    if (type == 'fork') return 'Mantente $direction$suffix';
    if (type == 'turn' || type == 'end of road') {
      return 'Gira $direction$suffix';
    }
    return 'Continúa $direction$suffix';
  }
}
