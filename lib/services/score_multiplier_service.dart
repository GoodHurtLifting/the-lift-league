class ScoreMultiplierService {
  static const double _calibrationConstant = 0.21;

  double getMultiplier({
    required int sets,
    required int repsPerSet,
    bool isBodyweight = false,
  }) {
    if (isBodyweight) return 0.0;
    if (sets <= 0 || repsPerSet <= 0) return 0.0;
    return _calibrationConstant / (sets * repsPerSet);
  }
}