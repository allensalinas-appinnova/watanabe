class DeviceInstallation {
  const DeviceInstallation({
    required this.id,
    required this.platform,
    required this.createdAt,
    required this.lastSeenAt,
    this.appVersion,
    this.buildNumber,
  });

  final String id;
  final String platform;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final String? appVersion;
  final String? buildNumber;
}
