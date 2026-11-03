import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Explains long waits without starting retries or changing the server lease.
class DocumentAnalysisProgress extends StatefulWidget {
  const DocumentAnalysisProgress({super.key});

  @override
  State<DocumentAnalysisProgress> createState() => _DocumentAnalysisProgressState();
}

class _DocumentAnalysisProgressState extends State<DocumentAnalysisProgress> {
  late final Timer _timer;
  bool _takingLonger = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _takingLonger = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(_takingLonger ? l.documentAnalysisTakingLonger : l.documentAnalyzing),
        ),
      ],
    );
  }
}
