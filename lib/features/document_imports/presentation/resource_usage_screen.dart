import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/document_import.dart';
import 'document_import_providers.dart';
import 'document_import_screen.dart';

String documentBytes(int bytes) => '${(bytes / 1000000).toStringAsFixed(1)} MB';

class ResourceUsageScreen extends ConsumerWidget {
  const ResourceUsageScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), user = ref.watch(authSessionProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l.resourceUsageTitle)),
      body: user == null || user.isAnonymous
          ? Center(child: Text(l.documentRegisteredOnly))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(resourceUsageProvider);
                await ref.read(resourceUsageProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ref
                      .watch(resourceUsageProvider)
                      .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => Column(
                          children: [
                            Text(l.documentRetryError),
                            TextButton(
                              onPressed: () => ref.invalidate(resourceUsageProvider),
                              child: Text(l.retry),
                            ),
                          ],
                        ),
                        data: (u) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.documentQuotaUsage(
                                u.dailyUsed,
                                u.dailyLimit,
                                u.monthlyUsed,
                                u.monthlyLimit,
                              ),
                            ),
                            if (u.dailyRenewsAt != null)
                              Text(
                                l.documentQuotaRenews(
                                  DateFormat.yMd(
                                    Localizations.localeOf(context).toString(),
                                  ).add_Hm().format(u.dailyRenewsAt!.toLocal()),
                                ),
                              ),
                            if (u.monthlyRenewsAt != null)
                              Text(
                                l.documentMonthlyRenews(
                                  DateFormat.yMd(
                                    Localizations.localeOf(context).toString(),
                                  ).add_Hm().format(u.monthlyRenewsAt!.toLocal()),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              l.documentStorageUsage(
                                documentBytes(u.attachmentBytes),
                                documentBytes(u.attachmentLimit),
                              ),
                            ),
                            LinearProgressIndicator(
                              value: (u.attachmentBytes / u.attachmentLimit).clamp(0, 1),
                            ),
                            const SizedBox(height: 8),
                            Text(l.documentTemporaryUsage(documentBytes(u.temporaryBytes))),
                            if (!u.enabled) Text(l.documentServiceDisabled),
                          ],
                        ),
                      ),
                  const SizedBox(height: 24),
                  Text(l.documentAttachments, style: Theme.of(context).textTheme.titleLarge),
                  Text(l.documentDeleteExplanation),
                  AttachmentList(uid: user.id),
                ],
              ),
            ),
    );
  }
}

class CompactAttachmentRow extends StatelessWidget {
  const CompactAttachmentRow({
    super.key,
    required this.contentType,
    required this.size,
    required this.onOpen,
    required this.onDelete,
    this.busy = false,
  });
  final String contentType;
  final int size;
  final VoidCallback onOpen, onDelete;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final format = contentType == 'application/pdf'
        ? 'PDF'
        : contentType.split('/').last.toUpperCase();
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: busy ? null : onOpen,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        contentType == 'application/pdf'
                            ? Icons.picture_as_pdf_outlined
                            : Icons.image_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(l.documentViewReceipt),
                          Text(
                            '$format · ${NumberFormat.decimalPatternDigits(locale: l.localeName, decimalDigits: 1).format(size / 1000000)} MB',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (busy)
          const SizedBox(
            width: 48,
            height: 48,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          PopupMenuButton<String>(
            tooltip: l.documentReceiptOptions,
            onSelected: (_) => onDelete(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'delete', child: Text(l.documentDeleteAttachment)),
            ],
          ),
      ],
    );
  }
}

class AttachmentList extends ConsumerStatefulWidget {
  const AttachmentList({
    super.key,
    required this.uid,
    this.operationId,
    this.attachmentId,
    this.compact = false,
  });
  final String uid;
  final String? operationId, attachmentId;
  final bool compact;
  @override
  ConsumerState<AttachmentList> createState() => _AttachmentListState();
}

class _AttachmentListState extends ConsumerState<AttachmentList> {
  final Set<String> _deleting = {};
  Future<void> _delete(DocumentAttachment a) async {
    if (_deleting.contains(a.id)) return;
    final l = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: Text(l.documentDeleteAttachment),
        content: Text(l.documentDeleteExplanation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.documentDelete)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _deleting.add(a.id));
    final result = await ref.read(documentImportRepositoryProvider).deleteAttachment(a);
    if (!mounted) return;
    setState(() => _deleting.remove(a.id));
    result.match(
      (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(documentError(l, f.message)))),
      (_) => ref.invalidate(resourceUsageProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        key = (uid: widget.uid, operationId: widget.operationId);
    final provider = widget.attachmentId == null
        ? documentAttachmentsProvider(key)
        : operationAttachmentProvider((uid: widget.uid, attachmentId: widget.attachmentId!));
    return ref
        .watch(provider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) =>
              TextButton(onPressed: () => ref.invalidate(provider), child: Text(l.retry)),
          data: (rows) => Column(
            children: [
              if (rows.isEmpty && !widget.compact) Text(l.documentAttachmentsEmpty),
              for (final a in rows)
                if (widget.compact)
                  CompactAttachmentRow(
                    key: ValueKey('compact_attachment_${a.id}'),
                    contentType: a.contentType,
                    size: a.size,
                    busy: _deleting.contains(a.id),
                    onOpen: () => context.push('/attachments/${a.id}'),
                    onDelete: () => _delete(a),
                  )
                else
                  ListTile(
                    leading: Icon(
                      a.contentType == 'application/pdf'
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                    ),
                    title: Text(l.documentReceipt),
                    subtitle: Text(documentBytes(a.size)),
                    onTap: () => context.push('/attachments/${a.id}'),
                    trailing: IconButton(
                      tooltip: l.documentDeleteAttachment,
                      onPressed: _deleting.contains(a.id) ? null : () => _delete(a),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
            ],
          ),
        );
  }
}

class AttachmentViewerScreen extends ConsumerWidget {
  const AttachmentViewerScreen({super.key, required this.attachmentId});
  final String attachmentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.documentReceipt)),
      body: ref
          .watch(documentAttachmentProvider(attachmentId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.documentReadError),
                  TextButton(
                    onPressed: () => ref.invalidate(documentAttachmentProvider(attachmentId)),
                    child: Text(l.retry),
                  ),
                ],
              ),
            ),
            data: (file) => DocumentPreview(file: file),
          ),
    );
  }
}
