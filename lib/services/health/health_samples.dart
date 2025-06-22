// Models representing generic health samples returned by providers.

enum HealthSampleType { weight, energy }

abstract class HealthSample {
  final DateTime date;
  final String source;
  final HealthSampleType type;

  const HealthSample({
    required this.date,
    required this.source,
    required this.type,
  });
}

class WeightSample extends HealthSample {
  final double? value;
  final double? bmi;
  final double? bodyFat;

  WeightSample({
    required DateTime date,
    required String source,
    this.value,
    this.bmi,
    this.bodyFat,
  }) : super(date: date, source: source, type: HealthSampleType.weight);
}

class EnergySample extends HealthSample {
  final double kcalIn;
  final double kcalOut;

  EnergySample({
    required DateTime date,
    required String source,
    required this.kcalIn,
    required this.kcalOut,
  }) : super(date: date, source: source, type: HealthSampleType.energy);
}

