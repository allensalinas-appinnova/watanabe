import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/pinned_action_bar.dart';
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
  static bool _timeZonesInitialized = false;

  Future<void> _changeReceipt(DocumentImportController controller, AppLocalizations l) async {
    final source = await showModalBottomSheet<DocumentFileSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l.documentCamera),
              onTap: () => Navigator.pop(sheetContext, DocumentFileSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.documentGallery),
              onTap: () => Navigator.pop(sheetContext, DocumentFileSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l.documentFile),
              onTap: () => Navigator.pop(sheetContext, DocumentFileSource.file),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await controller.prepareReplacement(source);
    if (!mounted) return;
    final state = ref.read(documentImportControllerProvider);
    if (state.replacementCandidate == null) return;
    final useNew = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.documentReplacementTitle),
        content: Text(l.documentReplacementBody),
        actions: [
          TextButton(
            key: const ValueKey('document_keep_current'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.documentKeepCurrent),
          ),
          FilledButton(
            key: const ValueKey('document_use_new'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.documentUseNew),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (useNew == true) {
      await controller.confirmReplacement();
    } else {
      controller.cancelReplacement();
    }
  }

  Future<void> _discardDraft(DocumentImportController controller, AppLocalizations l) async {
    final phase = ref.read(documentImportControllerProvider).session?.phase;
    if (phase == DocumentPhase.approved || phase == DocumentPhase.duplicate) {
      await controller.discard();
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.documentDiscard),
        content: Text(l.documentDiscardExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.documentDiscard),
          ),
        ],
      ),
    );
    if (yes == true) await controller.discard();
  }

  String _formatRenewal(DateTime instant, String zone, AppLocalizations l) {
    try {
      if (!_timeZonesInitialized) {
        timezone_data.initializeTimeZones();
        _timeZonesInitialized = true;
      }
      final local = timezone.TZDateTime.from(instant.toUtc(), timezone.getLocation(zone));
      return DateFormat.yMMMd(l.localeName).format(local);
    } catch (_) {
      return DateFormat.yMMMd(l.localeName).format(instant.toLocal());
    }
  }

  String _fileSize(int bytes, AppLocalizations l) => l.documentFileSize(
    '${NumberFormat.decimalPattern(l.localeName).format(bytes / 1000000)} MB',
  );

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
    final usage = ref.watch(resourceUsageProvider);
    final usageData = usage.valueOrNull;
    final dailyRemaining = usageData == null
        ? null
        : (usageData.dailyLimit - usageData.dailyUsed).clamp(0, usageData.dailyLimit);
    final monthlyRemaining = usageData == null
        ? null
        : (usageData.monthlyLimit - usageData.monthlyUsed).clamp(0, usageData.monthlyLimit);
    final analysesRemaining = dailyRemaining == null || monthlyRemaining == null
        ? null
        : dailyRemaining < monthlyRemaining
        ? dailyRemaining
        : monthlyRemaining;
    final quotaExhausted = usageData != null && analysesRemaining == 0;
    final serviceDisabled = usageData?.enabled == false;
    final analyzable =
        session == null || [DocumentPhase.prepared, DocumentPhase.failed].contains(session.phase);
    final canRetryExistingAnalysis = session?.phase == DocumentPhase.analyzing;
    final isUnsupported = session?.phase == DocumentPhase.unsupported;
    final showPrepareAction = state.draft != null && analyzable && !isUnsupported;

    Future<void> prepareExpense() async {
      if (quotaExhausted || serviceDisabled || state.busy) return;
      if (!await ref.read(documentConnectionProvider).hasNetwork()) {
        await controller.analyze();
        return;
      }
      if (!context.mounted) return;
      if (!_consent) {
        final yes = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(l.documentCloudTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.documentCloudSummary),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(l.documentMoreDetails),
                  children: [Text(l.documentCloudDetails)],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l.documentPrepareExpense),
              ),
            ],
          ),
        );
        if (yes != true || !mounted) return;
        _consent = true;
      }
      await controller.analyze();
    }

    Widget usageLine() => usage.when(
      data: (u) {
        if (!u.enabled) return Text(l.documentServiceDisabled);
        return Row(
          children: [
            Expanded(
              child: Text(
                l.documentUsageAvailable(analysesRemaining ?? 0),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/settings/usage'),
              child: Text(l.resourceUsageTitle),
            ),
          ],
        );
      },
      loading: () => Row(
        children: [
          Expanded(child: Text(l.resourceUsageTitle, style: Theme.of(context).textTheme.bodySmall)),
          TextButton(
            onPressed: () => context.push('/settings/usage'),
            child: Text(l.documentSeeUsage),
          ),
        ],
      ),
      error: (_, _) => Row(
        children: [
          Expanded(
            child: Text(l.documentUsageUnavailable, style: Theme.of(context).textTheme.bodySmall),
          ),
          IconButton(
            tooltip: l.retry,
            onPressed: () => ref.invalidate(resourceUsageProvider),
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: () => context.push('/settings/usage'),
            child: Text(l.resourceUsageTitle),
          ),
        ],
      ),
    );

    Widget quotaMessage() {
      if (usageData == null || !usageData.enabled || !quotaExhausted) {
        return const SizedBox.shrink();
      }
      final dailyIsBinding = dailyRemaining! <= monthlyRemaining!;
      final renewal = dailyIsBinding ? usageData.dailyRenewsAt : usageData.monthlyRenewsAt;
      if (renewal == null) return Text(l.documentQuotaExceeded);
      return Text(
        '${l.documentQuotaExceeded} ${l.documentQuotaRenewalAt(_formatRenewal(renewal, profile!.timeZone, l))}',
      );
    }

    final Widget body = user == null || user.isAnonymous
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
            key: const ValueKey('document_import_content'),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              Text(l.documentImportExplanation),
              const SizedBox(height: 8),
              usageLine(),
              if (state.busy && state.draft == null) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Semantics(liveRegion: true, child: Text(l.documentPreparingExpense)),
              ],
              if (!state.loaded) const LinearProgressIndicator(),
              if (state.draft == null) ...[
                const SizedBox(height: 12),
                for (final source in DocumentFileSource.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      key: ValueKey('document_pick_${source.name}'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: state.loaded && !state.busy
                          ? () => controller.select(source)
                          : null,
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
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) => Container(
                    height: (constraints.maxWidth * .72).clamp(180.0, 300.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: DocumentPreview(file: state.draft!.file),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        key: const ValueKey('document_preview'),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (dialogContext) => Dialog.fullscreen(
                            child: Scaffold(
                              appBar: AppBar(title: Text(l.documentPreview)),
                              body: DocumentPreview(file: state.draft!.file),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.zoom_in),
                        label: Text(l.documentPreview),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: l.documentMoreOptions,
                      enabled: !state.busy,
                      onSelected: (value) {
                        if (value == 'discard') _discardDraft(controller, l);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'discard', child: Text(l.documentDiscard)),
                      ],
                    ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${state.draft!.file.contentType == 'application/pdf' ? l.documentTypePdf : l.documentTypeImage} · ${_fileSize(state.draft!.file.bytes.length, l)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('document_change_receipt'),
                    onPressed: state.busy ? null : () => _changeReceipt(controller, l),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l.documentChangeReceipt),
                  ),
                ),
                if (state.replacementCandidate != null && !state.busy)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.documentReplacementBody),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                key: const ValueKey('document_cancel_replacement'),
                                onPressed: controller.cancelReplacement,
                                child: Text(l.documentKeepCurrent),
                              ),
                              FilledButton(
                                key: const ValueKey('document_retry_replacement'),
                                onPressed: controller.confirmReplacement,
                                child: Text(l.retry),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (state.busy)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.replacing
                              ? l.documentChangingReceiptProgress
                              : l.documentPreparingExpense,
                        ),
                      ),
                    ],
                  ),
                if (state.offline) Semantics(liveRegion: true, child: Text(l.documentOffline)),
                if (state.error != null)
                  Semantics(liveRegion: true, child: Text(documentError(l, state.error!.message))),
                if (!state.busy && state.error == null && session?.analysisIssue != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(switch (session!.analysisIssue!) {
                      DocumentAnalysisIssue.serviceBusy => l.documentServiceBusy,
                      DocumentAnalysisIssue.timedOut => l.documentAnalysisTimedOut,
                      DocumentAnalysisIssue.failed => l.documentAnalysisFailed,
                    }),
                  ),
                if (session?.phase == DocumentPhase.analyzing) const DocumentAnalysisProgress(),
                if (session?.phase == DocumentPhase.ready)
                  OutlinedButton.icon(
                    key: const ValueKey('document_review'),
                    onPressed: () => _openReview(session!),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(l.documentReview),
                  ),
                if (session?.phase == DocumentPhase.unsupported) ...[
                  Text(l.documentUnsupported),
                  const SizedBox(height: 8),
                  Text(l.documentManualDraftNote, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (session?.phase == DocumentPhase.duplicate ||
                    session?.phase == DocumentPhase.approved) ...[
                  Text(l.documentAlreadyImported),
                  if (session?.operationId != null)
                    TextButton(
                      onPressed: () => context.push('/operations/${session!.operationId}/edit'),
                      child: Text(l.documentOpenExisting),
                    ),
                ],
                if (canRetryExistingAnalysis && !state.busy)
                  TextButton(onPressed: controller.analyze, child: Text(l.retry)),
                if (quotaExhausted && analyzable) ...[
                  const SizedBox(height: 8),
                  quotaMessage(),
                ],
                if (isUnsupported || state.offline || state.error != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('document_manual_entry'),
                    onPressed: () => context.push('/operations/new?type=expense'),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l.documentManual),
                  ),
                  if (isUnsupported || state.offline)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l.documentManualDraftNote,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 12),
            ],
          );

    return Scaffold(
      appBar: AppBar(title: Text(l.documentImportTitle)),
      body: body,
      bottomNavigationBar:
          state.draft != null &&
              user != null &&
              !user.isAnonymous &&
              profile != null &&
              controller.belongsTo(user.id, profile.dataGeneration) &&
              !state.busy &&
              (showPrepareAction || isUnsupported || canRetryExistingAnalysis)
          ? SafeArea(
              top: false,
              child: PinnedActionBar(
                buttonKey: const ValueKey('document_prepare_expense'),
                icon: isUnsupported ? Icons.edit_outlined : Icons.auto_awesome_outlined,
                label: isUnsupported
                    ? l.documentManual
                    : canRetryExistingAnalysis
                    ? l.retry
                    : state.error != null || state.offline
                    ? l.retry
                    : l.documentPrepareExpense,
                onPressed: isUnsupported
                    ? () => context.push('/operations/new?type=expense')
                    : canRetryExistingAnalysis
                    ? controller.analyze
                    : (quotaExhausted || serviceDisabled ? null : prepareExpense),
              ),
            )
          : null,
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
