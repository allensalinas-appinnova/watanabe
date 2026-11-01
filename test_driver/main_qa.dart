import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/routing/app_router.dart';
import 'package:personal_finance/core/utils/request_id.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_providers.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/main.dart' as app;

/// QA-only entry point that enables Flutter Driver without exposing the
/// extension through the normal app entry point or release builds.
Future<void> main() async {
  if (!kDebugMode) {
    throw StateError('The QA entry point is available only in debug mode.');
  }

  enableFlutterDriverExtension(
    enableTextEntryEmulation: false,
    handler: (message) async {
      final firebase = Firebase.app();
      final user = FirebaseAuth.instanceFor(app: firebase).currentUser;
      if (message == 'qa.session') {
        return jsonEncode({
          'project': firebase.options.projectId,
          'appId': firebase.options.appId,
          'email': user?.email,
          'anonymous': user?.isAnonymous,
        });
      }
      final staging = message?.startsWith('qa.stageReceipt:') == true;
      if ((!staging && message != 'qa.resourceAccess') ||
          firebase.options.projectId != 'lumiomoney' ||
          user?.email?.toLowerCase() != 'allensalinasjaramillo@gmail.com' ||
          user?.isAnonymous != false) {
        return jsonEncode({'error': 'qa-preflight-required'});
      }
      try {
        if (staging) {
          final profile = await getIt<CanonicalFinanceRepository>()
              .watchUserProfile(user!.uid)
              .first;
          if (profile == null) return jsonEncode({'error': 'qa-profile-missing'});
          final repo = getIt<DocumentImportRepository>();
          final old = await repo.loadDraft(user.uid, profile.dataGeneration);
          if (old.isLeft() || old.getOrElse((_) => null) != null) {
            return jsonEncode({'error': 'qa-existing-draft'});
          }
          final bytes = base64Decode(message!.substring('qa.stageReceipt:'.length));
          if (bytes.length > 5000000) return jsonEncode({'error': 'qa-file-too-large'});
          final draft = DocumentDraft(
            file: DocumentFile(bytes: bytes, contentType: 'image/png'),
            importId: newRequestId(),
            generation: profile.dataGeneration,
          );
          final saved = await repo.saveDraft(user.uid, draft);
          if (saved.isLeft()) return jsonEncode({'error': 'qa-draft-save-failed'});
          final context = appRouter.routerDelegate.navigatorKey.currentContext!;
          ProviderScope.containerOf(context).invalidate(documentImportControllerProvider);
          unawaited(appRouter.push('/document-imports/new'));
          return jsonEncode({'staged': true, 'importId': draft.importId});
        }
        final token = await FirebaseAppCheck.instanceFor(app: firebase).getToken(true);
        await FirebaseFunctions.instanceFor(
          app: firebase,
          region: 'us-central1',
        ).httpsCallable('getResourceUsage').call<void>();
        return jsonEncode({
          'authenticated': true,
          'appCheck': token?.isNotEmpty == true,
          'usageRead': true,
        });
      } on FirebaseException catch (error) {
        return jsonEncode({'error': error.code, 'plugin': error.plugin});
      }
    },
  );
  await app.main();
}
