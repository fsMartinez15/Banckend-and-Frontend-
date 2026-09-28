import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:ridemove/data/open_route_adapter.dart';

// Manual network smoke check with two public landmarks; never run as a unit test.
Future<void> main() async {
  final client = http.Client();
  try {
    final planner = OpenRouteAdapter(client: client);
    final origin = (await planner.search('Universidad de Cundinamarca')).single;
    final destination = (await planner.search('Parque principal')).single;
    final route = await planner.route(origin.point, destination.point);
    stdout.writeln('${origin.name} -> ${destination.name}');
    stdout.writeln(
      '${route.points.length} road points; ${route.meters.round()} m; ${route.seconds.round()} s; ${route.steps.length} instructions',
    );
    for (final step in route.steps) {
      stdout.writeln(step.instruction);
    }
  } finally {
    client.close();
  }
}
