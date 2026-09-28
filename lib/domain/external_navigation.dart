/// Port for handing a destination to a turn-by-turn navigation application.
abstract interface class ExternalNavigation {
  Future<bool> navigateTo(String destination);
}
