import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_user_model.dart';

abstract interface class AuthLocalDataSource {
  Future<AuthUserModel?> readCachedUser();

  Future<void> cacheUser(AuthUserModel user);

  Future<void> clearCachedUser();
}

class SharedPreferencesAuthLocalDataSource implements AuthLocalDataSource {
  const SharedPreferencesAuthLocalDataSource({required SharedPreferences preferences})
    : _preferences = preferences;

  static const _userKey = 'auth.cached_user';

  final SharedPreferences _preferences;

  @override
  Future<AuthUserModel?> readCachedUser() async {
    final value = _preferences.getString(_userKey);
    if (value == null) return null;
    return AuthUserModel.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> cacheUser(AuthUserModel user) async {
    await _preferences.setString(_userKey, jsonEncode(user.toJson()));
  }

  @override
  Future<void> clearCachedUser() async {
    await _preferences.remove(_userKey);
  }
}
