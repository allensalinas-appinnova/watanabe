import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/device_registry_repository.dart';

class DeviceRegistryLifecycle extends ConsumerStatefulWidget {
  const DeviceRegistryLifecycle({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<DeviceRegistryLifecycle> createState() => _DeviceRegistryLifecycleState();
}

class _DeviceRegistryLifecycleState extends ConsumerState<DeviceRegistryLifecycle>
    with WidgetsBindingObserver {
  String? _registeredUid;
  String? _lastAttemptUid;
  bool _registrationInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _registerCurrentUser(force: true);
  }

  Future<void> _registerCurrentUser({bool force = false}) async {
    if (_registrationInProgress) return;
    final user = ref.read(authSessionProvider).valueOrNull;
    if (user == null || user.isAnonymous) {
      _registeredUid = null;
      _lastAttemptUid = null;
      return;
    }
    if (!force && user.id == _lastAttemptUid) return;
    _registrationInProgress = true;
    _lastAttemptUid = user.id;
    try {
      final result = await getIt<DeviceRegistryRepository>().registerCurrentInstallation();
      result.match((_) {}, (_) => _registeredUid = user.id);
    } on Object {
      // Best effort: app usage must not be blocked by analytics metadata.
    } finally {
      _registrationInProgress = false;
      final currentUser = ref.read(authSessionProvider).valueOrNull;
      if (mounted &&
          currentUser != null &&
          !currentUser.isAnonymous &&
          currentUser.id != _registeredUid &&
          currentUser.id != _lastAttemptUid) {
        unawaited(_registerCurrentUser());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user == null || user.isAnonymous) {
        _registeredUid = null;
      } else if (user.id != _registeredUid && user.id != _lastAttemptUid) {
        unawaited(_registerCurrentUser());
      }
    });
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user != null &&
        !user.isAnonymous &&
        user.id != _registeredUid &&
        user.id != _lastAttemptUid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_registerCurrentUser()));
    }
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
