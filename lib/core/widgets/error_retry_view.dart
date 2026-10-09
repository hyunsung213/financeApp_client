import 'package:flutter/material.dart';
import '../../data/api/api_error.dart';
import '../theme/wallet_glass.dart';

/// A load that failed: what didn't load, why in plain words
/// ([userErrorMessage], never the exception text), and a 다시 시도 button.
///
/// Kept visually distinct from a screen's empty state, so a failure is never
/// read as "there is nothing here".
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: glass.negative, size: 36),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: glass.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          userErrorMessage(error),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: glass.textSecondary),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}
