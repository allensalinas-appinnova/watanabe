import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

@freezed
sealed class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String id,
    required bool isAnonymous,
    String? email,
    String? displayName,
  }) = _AuthUser;
}
