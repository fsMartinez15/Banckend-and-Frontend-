import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/api_repository.dart';
import 'data/demo_repository.dart';
import 'data/geolocator_adapter.dart';
import 'data/waze_navigation_adapter.dart';
import 'data/open_route_adapter.dart';
import 'domain/ride_repository.dart';
import 'application/location_tracker.dart';
import 'presentation/app.dart';
export 'presentation/app.dart' show RideMoveApp;

/// Composition root: the only place that chooses concrete mobile adapters.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  const api = String.fromEnvironment('API_BASE_URL');
  RideRepository repository = DemoRepository();
  String? error;
  if (url.isNotEmpty || key.isNotEmpty) {
    try {
      if (url.isEmpty || key.isEmpty || api.isEmpty) {
        throw StateError('Falta configuración');
      }
      final uri = Uri.parse(api);
      if (!['https', 'http'].contains(uri.scheme) || uri.host.isEmpty) {
        throw StateError('URL de API inválida');
      }
      await Supabase.initialize(url: url, publishableKey: key);
      repository = ApiRepository(Supabase.instance.client, api);
    } catch (_) {
      error =
          'No se pudo iniciar la conexión. Configura SUPABASE_URL, SUPABASE_ANON_KEY y API_BASE_URL para el backend RideMove.';
    }
  }
  runApp(
    RideMoveApp(
      repository: repository,
      startupError: error,
      tracker: LocationTracker(GeolocatorAdapter(), repository),
      navigation: const WazeNavigationAdapter(),
      routePlanner: OpenRouteAdapter(
        geocoderUrl: const String.fromEnvironment(
          'GEOCODER_URL',
          defaultValue: 'https://photon.komoot.io',
        ),
        routerUrl: const String.fromEnvironment(
          'ROUTER_URL',
          defaultValue: 'https://router.project-osrm.org',
        ),
      ),
    ),
  );
}
