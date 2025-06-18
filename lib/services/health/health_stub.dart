class HealthDataPoint {
  const HealthDataPoint();
}

enum HealthDataType { STEPS, ACTIVE_ENERGY_BURNED }

class HealthFactory {
  final bool useHealthConnectIfAvailable;
  const HealthFactory({this.useHealthConnectIfAvailable = false});

  Future<bool> requestAuthorization(List<HealthDataType> types) async => false;
}
