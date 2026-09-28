import 'ride_repository.dart';

class RoutePlace {
  final String name, address;
  final Coordinates point;
  const RoutePlace(this.name, this.address, this.point);
}

class RouteStep {
  final String instruction;
  final double meters;
  const RouteStep(this.instruction, this.meters);
}

class RoadRoute {
  final List<Coordinates> points;
  final List<RouteStep> steps;
  final double meters, seconds;
  const RoadRoute({
    required this.points,
    required this.steps,
    required this.meters,
    required this.seconds,
  });
}

/// Routing port. Domain types have no Flutter, HTTP or mapping SDK dependencies.
abstract interface class RoutePlanner {
  Future<List<RoutePlace>> search(String address);
  Future<RoadRoute> route(Coordinates origin, Coordinates destination);
}
