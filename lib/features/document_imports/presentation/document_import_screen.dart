import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../finance/presentation/models/movement_save_result.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../finance/presentation/screens/canonical_operation_form_screen.dart';
import '../data/document_file_picker.dart';
import '../domain/document_import.dart';
import 'document_analysis_progress.dart';
import 'document_import_providers.dart';

String documentError(AppLocalizations l, String? code) {
  if (code == 'document-upload-required') return l.documentUploadRequired;
  if (code == 'document-source-unavailable') return l.documentSourceUnavailable;
  if (code == 'document-service-busy') return l.documentServiceBusy;
  if (code == 'document-analysis-timeout') return l.documentAnalysisTimedOut;
  if (code == 'document-response-timeout') return l.documentResponseTimedOut;
  if (code == 'document-analysis-failed') return l.documentAnalysisFailed;
  if (code == 'document-draft-unavailable') return l.documentDraftUnavailable;
  if (code?.contains('quota') == true) {
    return code!.contains('storage') ? l.documentStorageFull : l.documentQuotaExceeded;
  }
  if (code?.contains('disabled') == true) return l.documentServiceDisabled;
  if (code?.contains('stale') == true || code?.contains('expired') == true) {
    return l.documentExpired;
  }
  if (code?.contains('file') == true || code?.contains('pdf') == true) return l.documentFileInvalid;
  if (code?.contains('app-check') == true || code?.contains('unauthenticated') == true) {
    return l.documentDeviceVerification;
  }
  return l.documentRetryError;
}

class DocumentPreview extends StatelessWidget {
  const DocumentPreview({super.key, required this.file});
  final DocumentFile file;
  @override
  Widget build(BuildContext context) => file.contentType == 'application/pdf'
      ? PdfViewer.data(file.bytes, sourceName: 'receipt.pdf')
      : InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(
            child: Image.memory(
              file.bytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) =>
                  Text(AppLocalizations.of(context).documentFileInvalid),
              semanticLabel: AppLocalizations.of(context).documentPreview,
            ),
          ),
        );
}

class DocumentImportScreen extends ConsumerStatefulWidget {
  const DocumentImportScreen({super.key, this.returnHome = false, this.returnLocation});
  final bool returnHome;
  final String? returnLocation;
  @override
  ConsumerState<DocumentImportScreen> createState() => _DocumentImportScreenState();
}

/// An in-session completion path; deep links still work without this extra.
class DocumentReviewNavigation {
  const DocumentReviewNavigation(this.onSaved);
  final Future<void> Function(MovementSaveResult) onSaved;
}

class _DocumentImportScreenState extends ConsumerState<DocumentImportScreen> {
  bool _consent = false;
  String? _openedReview;
  bool _openingReview = false;
  bool _finishingReview = false;

  Future<void> _openReview(DocumentImport session) async {
    if (_openingReview || !mounted) return;
    final uid = ref.read(authSessionProvider).valueOrNull?.id;
    if (uid == null ||
        !ref.read(documentImportControllerProvider.notifier).belongsTo(uid, session.generation)) {
      return;
    }
    _openingReview = true;
    try {
      final result = await context.push<MovementSaveResult>(
        '/document-imports/${session.id}/review',
        extra: DocumentReviewNavigation(
          (result) => _finishReview(session, uid, result),
        ),
      );
      if (!mounted || ref.read(authSessionProvider).valueOrNull?.id != uid) return;
      if (result?.status != MovementSaveStatus.confirmed) return;
      await _finishReview(session, uid, result!);
    } finally {
      _openingReview = false;
    }
  }

  Future<void> _finishReview(
    DocumentImport session,
    String uid,
    MovementSaveResult result,
  ) async {
    if (_finishingReview || !mounted || ref.read(authSessionProvider).valueOrNull?.id != uid) {
      return;
    }
    _finishingReview = true;
    // Complete the owner flow explicitly: router refreshes can replace an
    // imperative match while the financial sources update after saving.
    await ref.read(documentImportControllerProvider.notifier).reload(uid, session.generation);
    if (!mounted || ref.read(authSessionProvider).valueOrNull?.id != uid) return;
    final target = Uri.tryParse(widget.returnLocation ?? '/home');
    final destination =
        !widget.returnHome &&
            target != null &&
            !target.hasScheme &&
            !target.hasAuthority &&
            target.path.startsWith('/') &&
            !target.path.startsWith('/document-imports')
        ? target.toString()
        : '/home';
    final message = AppLocalizations.of(context).expenseRegistered(
      CurrencyFormatter.formatMinor(result.amountMinor, result.currency),
    );
    final messenger = ScaffoldMessenger.of(context);
    // A single transition removes capture and review together, including when
    // their imperative matches were refreshed after the server confirmation.
    context.go(destination);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), user = ref.watch(authSessionProvider).valueOrNull;
    final profile = user == null
        ? null
        : ref.watch(canonicalUserProfileProvider(user.id)).valueOrNull;
    if (user != null && !user.isAnonymous && profile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(documentImportControllerProvider.notifier)
              .initialize(user.id, profile.dataGeneration);
        }
      });
    }
    final state = ref.watch(documentImportControllerProvider),
        controller = ref.read(documentImportControllerProvider.notifier);
    final session = state.session;
    if (user != null &&
        profile != null &&
        controller.belongsTo(user.id, profile.dataGeneration) &&
        !state.busy &&
        state.error == null &&
        session?.phase == DocumentPhase.ready) {
      final identity = '${user.id}/${session!.generation}/${session.id}';
      if (_openedReview != identity) {
        _openedReview = identity;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.isCurrent == true) _openReview(session);
        });
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.documentImportTitle)),
      body: user == null || user.isAnonymous
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.documentRegisteredOnly),
                    TextButton(
                      onPressed: () => context.push('/settings/secure-account'),
                      child: Text(l.guestSaveAccount),
                    ),
                  ],
                ),
              ),
            )
          : profile == null || !controller.belongsTo(user.id, profile.dataGeneration)
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Text(l.documentImportExplanation),
                ref
                    .watch(resourceUsageProvider)
                    .when(
                      data: (u) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          l.documentQuotaUsage(
                            u.dailyUsed,
                            u.dailyLimit,
                            u.monthlyUsed,
                            u.monthlyLimit,
                          ),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                TextButton(
                  onPressed: () => context.push('/settings/usage'),
                  child: Text(l.resourceUsageTitle),
                ),
                const SizedBox(height: 16),
                if (!state.loaded) const LinearProgressIndicator(),
                if (state.draft == null) ...[
                  for (final source in DocumentFileSource.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        key: ValueKey('document_pick_${source.name}'),
                        onPressed: state.loaded ? () => controller.select(source) : null,
                        icon: Icon(
                          source == DocumentFileSource.camera
                              ? Icons.camera_alt_outlined
                              : source == DocumentFileSource.gallery
                              ? Icons.photo_library_outlined
                              : Icons.picture_as_pdf_outlined,
                        ),
                        label: Text(
                          source == DocumentFileSource.camera
                              ? l.documentCamera
                              : source == DocumentFileSource.gallery
                              ? l.documentGallery
                              : l.documentFile,
                        ),
                      ),
                    ),
                ] else ...[
                  SizedBox(height: 220, child: DocumentPreview(file: state.draft!.file)),
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (c) => Dialog.fullscreen(
                        child: Scaffold(
                          appBar: AppBar(title: Text(l.documentPreview)),
                          body: DocumentPreview(file: state.draft!.file),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.zoom_in),
                    label: Text(l.documentPreview),
                  ),
                  if (state.offline) Semantics(liveRegion: true, child: Text(l.documentOffline)),
                  if (state.error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(documentError(l, state.error!.message)),
                    ),
                  if (!state.busy && state.error == null && session?.analysisIssue != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(switch (session!.analysisIssue!) {
                        DocumentAnalysisIssue.serviceBusy => l.documentServiceBusy,
                        DocumentAnalysisIssue.timedOut => l.documentAnalysisTimedOut,
                        DocumentAnalysisIssue.failed => l.documentAnalysisFailed,
                      }),
                    ),
                  if (state.busy || session?.phase == DocumentPhase.analyzing)
                    const DocumentAnalysisProgress(),
                  if (!state.busy && session?.phase == DocumentPhase.analyzing)
                    TextButton(onPressed: controller.analyze, child: Text(l.retry)),
                  if (session?.phase == DocumentPhase.unsupported) Text(l.documentUnsupported),
                  if (session?.phase == DocumentPhase.duplicate ||
                      session?.phase == DocumentPhase.approved) ...[
                    Text(l.documentAlreadyImported),
                    if (session?.operationId != null)
                      TextButton(
                        onPressed: () => context.push('/operations/${session!.operationId}/edit'),
                        child: Text(l.documentOpenExisting),
                      ),
                  ],
                  if (session?.phase == DocumentPhase.ready)
                    FilledButton(
                      key: const ValueKey('document_review'),
                      onPressed: () => _openReview(session!),
                      child: Text(l.documentReview),
                    ),
                  if (session == null ||
                      [DocumentPhase.prepared, DocumentPhase.failed].contains(session.phase))
                    FilledButton(
                      key: const ValueKey('document_analyze'),
                      onPressed: state.busy
                          ? null
                          : () async {
                              if (!await ref.read(documentConnectionProvider).hasNetwork()) {
                                await controller.analyze();
                                return;
                              }
                              if (!context.mounted) return;
                              if (!_consent) {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    scrollable: true,
                                    title: Text(l.documentCloudTitle),
                                    content: Text(l.documentCloudConsent),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, false),
                                        child: Text(l.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: Text(l.documentAnalyze),
                                      ),
                                    ],
                                  ),
                                );
                                if (yes != true) return;
                                _consent = true;
                              }
                              await controller.analyze();
                            },
                      child: Text(state.error == null ? l.documentAnalyze : l.retry),
                    ),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () async {
                            if (session?.phase == DocumentPhase.approved ||
                                session?.phase == DocumentPhase.duplicate) {
                              await controller.discard();
                              return;
                            }
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                scrollable: true,
                                title: Text(l.documentDiscard),
                                content: Text(l.documentDiscardExplanation),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: Text(l.cancel),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: Text(l.documentDiscard),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true) await controller.discard();
                          },
                    child: Text(
                      session?.phase == DocumentPhase.approved ||
                              session?.phase == DocumentPhase.duplicate
                          ? l.documentStartAnother
                          : l.documentDiscard,
                    ),
                  ),
                  if (session?.phase != DocumentPhase.approved &&
                      session?.phase != DocumentPhase.duplicate)
                    TextButton(
                      onPressed: () => context.push('/operations/new?type=expense'),
                      child: Text(l.documentManual),
                    ),
                ],
                if (state.draft == null && state.error != null)
                  Text(documentError(l, state.error!.message)),
              ],
            ),
    );
  }
}

class DocumentReviewRoute extends ConsumerWidget {
  const DocumentReviewRoute({super.key, required this.importId, this.onSaved});
  final String importId;
  final Future<void> Function(MovementSaveResult)? onSaved;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authSessionProvider).valueOrNull?.id, l = AppLocalizations.of(context);
    if (uid == null) return Scaffold(body: Center(child: Text(l.sessionExpired)));
    final state = ref.watch(documentSessionProvider((uid: uid, id: importId)));
    return state.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(body: Center(child: Text(l.documentRetryError))),
      data: (s) => s == null || s.phase != DocumentPhase.ready
          ? Scaffold(
              appBar: AppBar(title: Text(l.documentReview)),
              body: Center(
                child: Text(
                  s?.phase == DocumentPhase.approved
                      ? l.documentAlreadyImported
                      : l.documentExpired,
                ),
              ),
            )
          : CanonicalOperationFormScreen(
              onDocumentSaved: onSaved,
              documentImport: s,
              initialAccountId: s.suggestion.accountId,
              initialCategoryId: s.suggestion.categoryId,
              initialOccurredAt: s.suggestion.date,
            ),
    );
  }
}

final documentSessionProvider = FutureProvider.autoDispose
    .family<DocumentImport?, ({String uid, String id})>(
      (ref, key) => ref.watch(documentImportRepositoryProvider).watch(key.uid, key.id).first,
    );
