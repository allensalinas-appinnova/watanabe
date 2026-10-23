enum AppearanceMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppearanceMode(this.id);
  final String id;

  static AppearanceMode fromId(Object? value) => AppearanceMode.values.firstWhere(
    (mode) => mode.id == value,
    orElse: () => AppearanceMode.system,
  );
}

enum AppearancePalette {
  lumio('lumio'),
  classicBlue('classicBlue'),
  ocean('ocean'),
  plum('plum');

  const AppearancePalette(this.id);
  final String id;

  static AppearancePalette fromId(Object? value) => AppearancePalette.values.firstWhere(
    (palette) => palette.id == value,
    orElse: () => AppearancePalette.lumio,
  );
}

class AppearancePreferences {
  const AppearancePreferences({
    this.mode = AppearanceMode.system,
    this.palette = AppearancePalette.lumio,
  });

  factory AppearancePreferences.fromMap(Object? value) {
    if (value is! Map) return const AppearancePreferences();
    return AppearancePreferences(
      mode: AppearanceMode.fromId(value['mode']),
      palette: AppearancePalette.fromId(value['palette']),
    );
  }

  final AppearanceMode mode;
  final AppearancePalette palette;

  Map<String, String> toMap() => {'mode': mode.id, 'palette': palette.id};

  @override
  bool operator ==(Object other) =>
      other is AppearancePreferences && other.mode == mode && other.palette == palette;

  @override
  int get hashCode => Object.hash(mode, palette);
}
