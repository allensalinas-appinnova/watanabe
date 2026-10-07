import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'failure.dart';

abstract final class FirebaseFailureMapper {
  static Failure fromException(Object error) {
    if (error is FirebaseAuthException) {
      if (error.code == 'network-request-failed') {
        return const NetworkFailure('No hay conexión. El movimiento queda pendiente.');
      }
      return AuthFailure(_authMessage(error.code));
    }

    if (error is FirebaseException) {
      return switch (error.code) {
        'unavailable' || 'deadline-exceeded' || 'network-request-failed' => const NetworkFailure(
          'No hay conexión. El movimiento queda pendiente.',
        ),
        'permission-denied' ||
        'unauthenticated' => const AuthFailure('La sesión necesita actualizarse.'),
        _ => const UnknownFailure('No pudimos completar la operación.'),
      };
    }
    if (error is SocketException) {
      return const NetworkFailure('No hay conexión. El movimiento queda pendiente.');
    }

    return const UnknownFailure('No pudimos completar la operación.');
  }

  static String _authMessage(String code) {
    return switch (code) {
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'El correo o la contraseña no son válidos.',
      'email-already-in-use' => 'Ya existe una cuenta con este correo.',
      'weak-password' => 'La contraseña debe ser más segura.',
      'network-request-failed' => 'No hay conexión. Inténtalo nuevamente.',
      'web-context-canceled' => 'Cancelaste el inicio de sesión con Google.',
      _ => 'No pudimos completar la autenticación.',
    };
  }
}
