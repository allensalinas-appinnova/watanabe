import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../../../core/error/failure.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/request_id.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/document_connection.dart';
import '../data/document_file_picker.dart';
import '../domain/document_import.dart';

final documentImportRepositoryProvider = Provider<DocumentImportRepository>((ref) => getIt());
final documentFilePickerProvider = Provider<DocumentFilePicker>((ref) => DocumentFilePicker());
final documentConnectionProvider = Provider<DocumentConnection>((ref) => DocumentConnection());
final resourceUsageProvider = FutureProvider.autoDispose<UsageSummary>(
  (ref) async {
    ref.watch(authSessionProvider.select((s) => s.valueOrNull?.id));
    return (await ref.watch(documentImportRepositoryProvider).usage()).match(
      (f) => throw StateError(f.message),
      (v) => v,
    );
  },
);
final documentAttachmentsProvider = StreamProvider.autoDispose
    .family<List<DocumentAttachment>, ({String uid, String? operationId})>(
      (ref, key) => ref
          .watch(documentImportRepositoryProvider)
          .attachments(key.uid, operationId: key.operationId),
    );
final operationAttachmentProvider = StreamProvider.autoDispose
    .family<List<DocumentAttachment>, ({String uid, String attachmentId})>(
      (ref, key) => ref
          .watch(documentImportRepositoryProvider)
          .attachments(key.uid, attachmentId: key.attachmentId),
    );
final documentAttachmentProvider = FutureProvider.autoDispose.family<DocumentFile, String>(
  (ref, id) async {
    ref.watch(authSessionProvider.select((s) => s.valueOrNull?.id));
    return (await ref.watch(documentImportRepositoryProvider).readAttachment(id)).match(
      (f) => throw StateError(f.message),
      (v) => v,
    );
  },
);

class DocumentImportState {
  const DocumentImportState({
    this.draft,
    this.replacementCandidate,
    this.session,
    this.busy = false,
    this.replacing = false,
    this.loaded = false,
    this.error,
    this.offline = false,
  });
  final DocumentDraft? draft;
  final DocumentDraft? replacementCandidate;
  final DocumentImport? session;
  final bool busy, replacing, loaded, offline;
  final Failure? error;
}

final documentImportControllerProvider =
    NotifierProvider<DocumentImportController, DocumentImportState>(DocumentImportController.new);

class DocumentImportController extends Notifier<DocumentImportState> {
  String? _uid;
  int? _generation;
  int _epoch = 0;
  StreamSubscription<DocumentImport?>? _subscription;
  @override
  DocumentImportState build() {
    ref.onDispose(() => _subscription?.cancel());
    ref.listen(authSessionProvider, (previous, next) {
      if (_uid != null && next.valueOrNull?.id != _uid) {
        _epoch++;
        _uid = null;
        _generation = null;
        _subscription?.cancel();
        state = const DocumentImportState();
      }
    });
    return const DocumentImportState();
  }

  bool belongsTo(String uid, int generation) => _uid == uid && _generation == generation;

  DocumentImportRepository get _repo => ref.read(documentImportRepositoryProvider);
  Future<void> initialize(String uid, int generation) async {
    if (_uid == uid && _generation == generation) return;
    final epoch = ++_epoch;
    await _subscription?.cancel();
    if (epoch != _epoch) return;
    _uid = uid;
    _generation = generation;
    state = const DocumentImportState(busy: true);
    final result = await _repo.loadDraft(uid, generation);
    if (epoch != _epoch || _uid != uid || _generation != generation) return;
    result.match((f) => state = DocumentImportState(loaded: true, error: f), (draft) {
      state = DocumentImportState(draft: draft, loaded: true);
      if (draft != null) _listen(draft.importId);
    });
    try {
      unawaited(_repo.retryPendingCleanup(uid));
    } catch (_) {
      // Cleanup is best-effort and must not block access to the active draft.
    }
  }

  Future<void> reload(String uid, int generation) async {
    _uid = null;
    await initialize(uid, generation);
  }

  void _listen(String id) {
    _subscription?.cancel();
    _subscription = _repo
        .watch(_uid!, id)
        .listen(
          (session) {
            if (state.draft?.importId != id) return;
            final resolved = [
              DocumentPhase.ready,
              DocumentPhase.unsupported,
              DocumentPhase.approved,
              DocumentPhase.duplicate,
            ].contains(session?.phase);
            state = DocumentImportState(
              draft: state.draft,
              replacementCandidate: state.replacementCandidate,
              session: session,
              loaded: true,
              busy: state.busy,
              replacing: state.replacing,
              error: resolved ? null : state.error,
              offline: resolved ? false : state.offline,
            );
          },
          onError: (Object _) {
            state = DocumentImportState(
              draft: state.draft,
              replacementCandidate: state.replacementCandidate,
              session: state.session,
              loaded: true,
              replacing: state.replacing,
              error: const NetworkFailure('document-network'),
            );
          },
        );
  }

  Future<void> select(DocumentFileSource source) async {
    if (state.busy || state.draft != null || _uid == null || _generation == null) return;
    final epoch = _epoch, uid = _uid!, generation = _generation!;
    state = const DocumentImportState(busy: true, loaded: true);
    try {
      final file = await ref.read(documentFilePickerProvider).pick(source);
      if (epoch != _epoch) return;
      if (file == null) {
        state = const DocumentImportState(loaded: true);
        return;
      }
      final draft = DocumentDraft(file: file, importId: newRequestId(), generation: generation);
      final saved = await _repo.saveDraft(uid, draft);
      if (epoch != _epoch) return;
      saved.match((f) => state = DocumentImportState(loaded: true, error: f), (v) {
        state = DocumentImportState(draft: draft, loaded: true);
        _listen(draft.importId);
      });
    } catch (_) {
      if (epoch != _epoch) return;
      state = const DocumentImportState(
        loaded: true,
        error: UnknownFailure('document-file-invalid'),
      );
    }
  }

  Future<void> prepareReplacement(DocumentFileSource source) async {
    final current = state.draft;
    if (state.busy || current == null || _uid == null || _generation == null) return;
    final epoch = _epoch;
    state = DocumentImportState(
      draft: current,
      session: state.session,
      busy: true,
      replacing: true,
      loaded: true,
    );
    try {
      final file = await ref.read(documentFilePickerProvider).pick(source);
      if (epoch != _epoch) return;
      state = DocumentImportState(
        draft: current,
        session: state.session,
        replacementCandidate: file == null
            ? null
            : DocumentDraft(file: file, importId: newRequestId(), generation: current.generation),
        loaded: true,
        replacing: false,
      );
    } catch (_) {
      if (epoch != _epoch) return;
      state = DocumentImportState(
        draft: current,
        session: state.session,
        loaded: true,
        replacing: false,
        error: const UnknownFailure('document-file-invalid'),
      );
    }
  }

  void cancelReplacement() {
    final current = state.draft;
    if (current == null) return;
    state = DocumentImportState(
      draft: current,
      session: state.session,
      loaded: true,
      offline: state.offline,
    );
  }

  Future<void> confirmReplacement() async {
    final current = state.draft, candidate = state.replacementCandidate;
    final uid = _uid, generation = _generation;
    if (state.busy || current == null || candidate == null || uid == null || generation == null) {
      return;
    }
    final epoch = _epoch, session = state.session;
    state = DocumentImportState(
      draft: current,
      session: session,
      replacementCandidate: candidate,
      busy: true,
      replacing: true,
      loaded: true,
    );
    final terminalPhase =
        session != null &&
        [
          DocumentPhase.approved,
          DocumentPhase.duplicate,
          DocumentPhase.discarded,
          DocumentPhase.expired,
        ].contains(session.phase);
    final result = await _repo.replaceDraft(
      uid,
      current.importId,
      candidate,
      cleanupPreviousImport:
          !terminalPhase && (session != null || current.review['serverAttempted'] == true),
      previousGeneration: current.generation,
    );
    if (epoch != _epoch || _uid != uid || _generation != generation) return;
    result.match(
      (failure) => state = DocumentImportState(
        draft: current,
        session: session,
        replacementCandidate: candidate,
        loaded: true,
        replacing: false,
        error: failure,
      ),
      (_) {
        _subscription?.cancel();
        state = DocumentImportState(draft: candidate, loaded: true, replacing: false);
        _listen(candidate.importId);
      },
    );
  }

  Future<void> analyze() async {
    final draft = state.draft;
    final epoch = _epoch;
    if (draft == null || state.busy) return;
    state = DocumentImportState(draft: draft, session: state.session, busy: true, loaded: true);
    final online = await ref.read(documentConnectionProvider).hasNetwork();
    if (epoch != _epoch) return;
    if (!online) {
      state = DocumentImportState(
        draft: draft,
        session: state.session,
        loaded: true,
        offline: true,
      );
      return;
    }
    state = DocumentImportState(draft: draft, session: state.session, busy: true, loaded: true);
    final attempted = DocumentDraft(
      file: draft.file,
      importId: draft.importId,
      generation: draft.generation,
      review: {...draft.review, 'serverAttempted': true},
    );
    final saved = await _repo.saveDraft(_uid!, attempted);
    if (epoch != _epoch) return;
    if (saved.isLeft()) {
      state = DocumentImportState(draft: draft, loaded: true, error: saved.getLeft().toNullable());
      return;
    }
    state = DocumentImportState(draft: attempted, session: state.session, busy: true, loaded: true);
    final prepared = await _repo.prepare(attempted);
    if (epoch != _epoch) return;
    await prepared.match<Future<void>>(
      (f) async {
        state = DocumentImportState(
          draft: attempted,
          session: state.session,
          loaded: true,
          error: f,
          offline:
              f.message == 'document-network' ||
              (f.technicalCode == 'unavailable' && !f.message.startsWith('document-')),
        );
      },
      (session) async {
        if (session.phase == DocumentPhase.duplicate || session.phase == DocumentPhase.approved) {
          state = DocumentImportState(draft: attempted, session: session, loaded: true);
          return;
        }
        final result =
            session.phase == DocumentPhase.ready || session.phase == DocumentPhase.unsupported
            ? prepared
            : await _repo.analyze(session);
        if (epoch != _epoch) return;
        result.match(
          (f) => state = DocumentImportState(
            draft: attempted,
            session: session,
            loaded: true,
            error: f,
            offline:
                f.message == 'document-network' ||
                (f.technicalCode == 'unavailable' && !f.message.startsWith('document-')),
          ),
          (v) => state = DocumentImportState(draft: attempted, session: v, loaded: true),
        );
      },
    );
    ref.invalidate(resourceUsageProvider);
  }

  Future<void> discard() async {
    final draft = state.draft;
    if (draft == null || state.busy) return;
    if (state.session?.phase == DocumentPhase.approved ||
        state.session?.phase == DocumentPhase.duplicate) {
      await _repo.clearDraft(_uid!);
    } else if (state.session != null || draft.review['serverAttempted'] == true) {
      final result = await _repo.discard(draft.importId, draft.generation);
      if (result.isLeft()) {
        state = DocumentImportState(
          draft: draft,
          session: state.session,
          loaded: true,
          error: result.getLeft().toNullable(),
        );
        return;
      }
    } else {
      await _repo.clearDraft(_uid!);
    }
    await _subscription?.cancel();
    state = const DocumentImportState(loaded: true);
    ref.invalidate(resourceUsageProvider);
  }
}
