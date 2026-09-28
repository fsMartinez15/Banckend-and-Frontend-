import 'package:url_launcher/url_launcher.dart';
import '../domain/external_navigation.dart';

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
}
