import 'package:url_launcher/url_launcher.dart';
import '../domain/external_navigation.dart';
import '../domain/ride_repository.dart';

class WazeNavigationAdapter implements ExternalNavigation {
  const WazeNavigationAdapter();
  @override
  Future<bool> navigateTo(String destination) => launchUrl(
    Uri.https('waze.com', '/ul', {
      'q': destination,
      'navigate': 'yes',
      'utm_source': 'ridemove',
    }),
    mode: LaunchMode.externalApplication,
  );

  @override
  Future<bool> navigateToPoint(Coordinates point) => launchUrl(
    Uri.https('waze.com', '/ul', {
      'll':
          '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
      'navigate': 'yes',
      'utm_source': 'ridemove',
    }),
    mode: LaunchMode.externalApplication,
  );

  @override
  Future<bool> call(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return Future.value(false);
    return launchUrl(Uri(scheme: 'tel', path: digits));
  }

  @override
  Future<bool> openUrl(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
