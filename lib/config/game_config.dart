class GameConfig {
  static const int startingCredits = 5000;
  static const int startingPower = 200;
  static const int maxPower = 200;
  static const int powerRegenRate = 5;
  static const int heatDecayRate = 1;
  static const int salaryPayIntervalMinutes = 60;
  static const int operationCheckIntervalSeconds = 10;
  static const int passiveIncomeIntervalMinutes = 5;
  static const double heatPenaltyMultiplier = 0.1;

  static const Map<String, int> serverClassPowerCost = {
    'basic': 5,
    'advanced': 25,
    'premium': 60,
    'elite': 100,
    'legendary': 150,
  };

  static const Map<String, double> operationSuccessBonus = {
    'data_theft': 0.0,
    'ddos': -0.1,
    'ransomware': -0.15,
    'espionage': -0.05,
    'crypto_mining': 0.05,
    'identity_theft': -0.2,
  };

  static const Map<String, int> operationHeatMultiplier = {
    'data_theft': 1,
    'ddos': 2,
    'ransomware': 3,
    'espionage': 1,
    'crypto_mining': 1,
    'identity_theft': 2,
  };
}
