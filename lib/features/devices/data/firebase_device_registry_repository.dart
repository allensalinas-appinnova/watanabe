import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/firebase_failure_mapper.dart';
import '../domain/device_installation.dart';
import '../domain/device_registry_repository.dart';

class FirebaseDeviceRegistryRepository implements DeviceRegistryRepository {
  FirebaseDeviceRegistryRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
    required SharedPreferences preferences,
  }) : _firestore = firestore,
       _functions = functions,
       _auth = auth,
       _preferences = preferences;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final SharedPreferences _preferences;
  static const _installationKey = 'device_registry_installation_id_v1';

  @override
  Stream<List<DeviceInstallation>> watchInstallations(String userId) {
    return _firestore.collection('users').doc(userId).collection('devices').snapshots().map((
      snapshot,
    ) {
      final now = DateTime.now();
      final active =
          snapshot.docs
              .map((doc) {
                final data = doc.data();
                return DeviceInstallation(
                  id: doc.id,
                  platform: data['platform'] as String? ?? 'unknown',
                  createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                  lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
                );
              })
              .where(
                (device) =>
                    device.lastSeenAt != null &&
                    now.difference(device.lastSeenAt!) < const Duration(days: 90),
              )
              .toList()
            ..sort((a, b) => b.lastSeenAt!.compareTo(a.lastSeenAt!));
      return active;
    });
  }

  @override
  Future<Either<Failure, void>> registerCurrentInstallation() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return const Right(null);
    try {
      final installationId = await _installationId();
      await _functions.httpsCallable('manageDevice').call<Map<String, dynamic>>({
        'action': 'register',
        'installationId': installationId,
        'platform': _platform,
      });
      return const Right(null);
    } on Object catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, void>> removeInstallation(String installationId) async {
    try {
      await _functions.httpsCallable('manageDevice').call<Map<String, dynamic>>({
        'action': 'remove',
        'installationId': installationId,
      });
      return const Right(null);
    } on Object catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  Future<String> _installationId() async {
    final existing = _preferences.getString(_installationKey);
    if (existing != null && _uuid.hasMatch(existing)) return existing;
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _preferences.setString(_installationKey, id);
    return id;
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'web',
    };
  }

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
}
