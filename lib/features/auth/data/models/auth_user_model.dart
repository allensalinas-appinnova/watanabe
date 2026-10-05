import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/auth_user.dart';

part 'auth_user_model.freezed.dart';
part 'auth_user_model.g.dart';

@freezed
sealed class AuthUserModel with _$AuthUserModel {
  const factory AuthUserModel({
    required String id,
    required bool isAnonymous,
    String? email,
    String? displayName,
  }) = _AuthUserModel;

  const AuthUserModel._();

  factory AuthUserModel.fromJson(Map<String, dynamic> json) => _$AuthUserModelFromJson(json);

  AuthUser toEntity() {
    return AuthUser(
      id: id,
      isAnonymous: isAnonymous,
      email: email,
      displayName: displayName,
    );
  }
}
