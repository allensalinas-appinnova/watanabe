import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:personal_finance/features/auth/data/models/auth_user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('legacy cache without creation date remains compatible', () {
    final user = AuthUserModel.fromJson({
      'id': 'old',
      'isAnonymous': false,
      'email': 'old@example.test',
    });
    expect(user.createdAt, isNull);
    expect(user.providerIds, isNull);
    expect(user.emailVerified, isNull);
    expect(user.toEntity().createdAt, isNull);
    expect(user.email, 'old@example.test');
  });
  test('creation metadata survives cache serialization and domain mapping', () async {
    final createdAt = DateTime.utc(2020, 4, 15, 15);
    final user = AuthUserModel(
      id: 'qa',
      isAnonymous: false,
      email: 'qa@example.test',
      createdAt: createdAt,
      providerIds: const ['apple.com', 'google.com'],
      emailVerified: true,
    );
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesAuthLocalDataSource(
      preferences: await SharedPreferences.getInstance(),
    );
    await store.cacheUser(user);
    final cached = await store.readCachedUser();
    expect(cached, user);
    expect(cached!.toEntity().createdAt, createdAt);
    expect(cached.toEntity().providerIds, ['apple.com', 'google.com']);
    expect(cached.toEntity().emailVerified, true);
    expect(
      AuthUserModel.fromJson(jsonDecode(jsonEncode(user.toJson())) as Map<String, dynamic>),
      user,
    );
    await store.clearCachedUser();
    expect(await store.readCachedUser(), isNull);
  });
}
