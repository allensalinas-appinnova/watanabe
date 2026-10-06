enum AppEnvironment {
  dev,
  staging,
  prod;

  static AppEnvironment fromDartDefine() {
    const value = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    for (final environment in AppEnvironment.values) {
      if (environment.name == value) return environment;
    }
    throw StateError('APP_ENV must be one of: dev, staging, prod. Received: $value');
  }

  void validate({required bool useEmulators, required bool isRelease}) {
    if (useEmulators && this != dev) {
      throw StateError('Firebase Emulator Suite is only allowed with APP_ENV=dev.');
    }
    if (useEmulators && isRelease) {
      throw StateError('Firebase Emulator Suite cannot be used in a release build.');
    }
  }
}
