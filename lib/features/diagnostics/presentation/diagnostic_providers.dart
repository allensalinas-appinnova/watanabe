import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/di/injection.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../coach/presentation/providers/coach_providers.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import '../data/firebase_diagnostic_repository.dart';
import '../domain/diagnostic_engine.dart';
import '../domain/diagnostic_repository.dart';

final diagnosticRepositoryProvider = Provider<DiagnosticRepository>(
  (ref) => FirebaseDiagnosticRepository(
    getIt<FirebaseFirestore>(),
    FirebaseFunctions.instanceFor(app: FirebaseBootstrap.app, region: 'us-central1'),
    getIt<FirebaseAuth>(),
  ),
);
final diagnosticSnapshotProvider = StreamProvider.autoDispose.family<DiagnosticSnapshot, String>((
  ref,
  uid,
) {
  final profileZone = ref.watch(
    canonicalUserProfileProvider(uid).select((value) => value.valueOrNull?.timeZone),
  );
  final calendar = ref.watch(coachRoutineProvider).calendar;
  ref.watch(
    coachTickProvider.select((state) {
      final instant = state.valueOrNull;
      if (instant == null || profileZone == null) return '';
      return diagnosticDate(calendar.local(instant, profileZone));
    }),
  );
  final routine = ref.watch(coachRoutineProvider);
  final profile = ref.watch(canonicalUserProfileProvider(uid));
  if (profile.hasError) return Stream.error(StateError('diagnostic-profile-unavailable'));
  if (!profile.hasValue || profile.value == null) return const Stream.empty();
  if (profile.value!.resetStatus != 'ready') {
    return Stream.error(StateError('diagnostic-profile-unavailable'));
  }
  final today = routine.today(profile.value!.timeZone);
  final location = tz.getLocation(profile.value!.timeZone);
  final start = tz.TZDateTime(location, today.year, today.month - 12).toUtc();
  final pending =
      ref.watch(pendingOperationsProvider).valueOrNull?.any((operation) {
        final payload = jsonDecode(operation.payload) as Map<String, dynamic>;
        return payload['ownerUserId'] == uid || !payload.containsKey('ownerUserId');
      }) ??
      false;
  return ref.watch(diagnosticRepositoryProvider).watch(uid, today, start).map((snapshot) {
    final input = snapshot.input;
    return DiagnosticSnapshot(
      DiagnosticInput(
        today: input.today,
        accounts: input.accounts,
        operations: input.operations,
        entries: input.entries,
        plan: input.plan,
        records: input.records,
        allocationIncomplete: input.allocationIncomplete,
        cached: input.cached,
        pending: input.pending || pending,
      ),
      snapshot.revisions,
      valuations: snapshot.valuations,
    );
  });
});
