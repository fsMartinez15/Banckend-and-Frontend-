import 'ride_repository.dart';

/// Port for handing a destination to a turn-by-turn navigation application.
abstract interface class ExternalNavigation {
  Future<bool> navigateTo(String destination);

  /// Navegación por voz hacia unas coordenadas exactas.
  Future<bool> navigateToPoint(Coordinates point);

  /// Abre el marcador telefónico.
  Future<bool> call(String phone);

  /// Abre una página externa (checkout de Wompi).
  Future<bool> openUrl(String url);
}
