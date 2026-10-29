import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/fare.dart';
import '../domain/ride_repository.dart';

/// Mobile outbound adapter. Auth uses Supabase; all business data uses the hexagonal API.
class ApiRepository implements RideRepository {
  final SupabaseClient auth;
  final String baseUrl;
  final http.Client transport;
  ApiRepository(this.auth, String baseUrl, {http.Client? transport})
    : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      transport = transport ?? http.Client();
  @override
  bool get demo => false;
  @override
  bool get signedIn => auth.auth.currentSession != null;
  @override
  Future<void> signIn(String email, String password) async {
    try {
      await auth.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw AppFailure(e.message);
    }
  }

  @override
  Future<bool> signUp(
    String email,
    String password,
    String name,
    String role, {
    String document = '',
  }) async {
    try {
      final result = await auth.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
          if (document.isNotEmpty) 'document_type': 'CC',
          if (document.isNotEmpty) 'document_number': document,
        },
      );
      return result.session != null;
    } on AuthException catch (e) {
      throw AppFailure(e.message);
    }
  }

  @override
  Future<void> signOut() => auth.auth.signOut();
  Future<dynamic> request(String method, String path, [JsonRow? body]) async {
    final session = auth.auth.currentSession;
    if (session == null) {
      throw const AppFailure('Inicia sesión para continuar.');
    }
    final req = http.Request(method, Uri.parse('$baseUrl/api/$path'))
      ..headers.addAll({
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      });
    if (body != null) {
      req.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await transport.send(req).timeout(const Duration(seconds: 25)),
    );
    final parsed = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw AppFailure(
        parsed is Map
            ? '${parsed['message'] ?? 'No se pudo completar la operación'}'
            : 'Error del servicio',
      );
    }
    return parsed;
  }

  @override
  Future<JsonRow> profile() async =>
      Map<String, dynamic>.from(await request('GET', 'profile'));
  Future<List<JsonRow>> list(String resource) async =>
      (await request('GET', resource) as List)
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
  @override
  Future<List<JsonRow>> trips() => list('trips');
  @override
  Future<List<JsonRow>> users() => list('profiles');
  @override
  Future<List<JsonRow>> vehicles() => list('vehicles');
  @override
  Future<List<JsonRow>> locations() => list('locations');
  @override
  Future<Tariff> tariff() async {
    try {
      return Tariff.fromJson(
        Map<String, dynamic>.from(await request('GET', 'tariff')),
      );
    } catch (_) {
      return Tariff.standard;
    }
  }

  @override
  Future<List<Coordinates>> nearbyDrivers(Coordinates around) async {
    final rows = await request(
      'GET',
      'drivers/nearby?lat=${around.latitude}&lng=${around.longitude}',
    );
    return (rows as List)
        .map(
          (r) => Coordinates(
            (r['latitude'] as num).toDouble(),
            (r['longitude'] as num).toDouble(),
          ),
        )
        .toList();
  }

  @override
  Future<List<JsonRow>> payments() async {
    try {
      return await list('payments');
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String> checkoutUrl(String tripId) async {
    final link = await request('POST', 'payments/checkout', {'tripId': tripId});
    return '${link['url']}';
  }

  @override
  Future<void> command(String name, JsonRow p) async {
    final id = Uri.encodeComponent('${p['p_id']}');
    final (method, path, body) = switch (name) {
      'create_trip' || 'request_trip' => (
        'POST',
        'trips',
        {
          for (final e in p.entries)
            if (e.value != null) e.key.replaceFirst('p_', ''): e.value,
        },
      ),
      'transition_trip' => (
        'PUT',
        'trips/$id/status',
        {'status': p['p_status']},
      ),
      'reject_trip' => ('POST', 'trips/$id/rejections', <String, dynamic>{}),
      'rate_trip' => (
        'POST',
        'trips/$id/rating',
        {'rating': p['p_rating'], 'comment': p['p_comment']},
      ),
      'save_profile' => (
        'PUT',
        'profile',
        {'name': p['p_name'], 'phone': p['p_phone']},
      ),
      'set_availability' => (
        'PUT',
        'availability',
        {'available': p['p_available']},
      ),
      'admin_set_active' => (
        'PUT',
        'profiles/$id/access',
        {'active': p['p_active']},
      ),
      'save_vehicle' => (
        'PUT',
        'vehicle',
        {for (final e in p.entries) e.key.replaceFirst('p_', ''): e.value},
      ),
      'save_location' => (
        'PUT',
        'location',
        {'latitude': p['p_latitude'], 'longitude': p['p_longitude']},
      ),
      _ => throw const AppFailure('Operación desconocida'),
    };
    await request(method, path, body);
  }
}
