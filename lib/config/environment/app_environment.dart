enum AppEnvironment {
  dev,
  staging,
  prod;

  static AppEnvironment fromDartDefine() {
    const value = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    return AppEnvironment.values.firstWhere(
      (environment) => environment.name == value,
      orElse: () => AppEnvironment.dev,
    );
  }
}
