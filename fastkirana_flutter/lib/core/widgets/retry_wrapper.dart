import 'package:flutter/material.dart';

class RetryWrapper extends StatelessWidget {
  final bool isLoading;
  final Object? error;
  final VoidCallback? onRetry;
  final Widget? child;
  final String? retryLabel;

  const RetryWrapper({
    super.key,
    required this.isLoading,
    this.error,
    this.onRetry,
    this.child,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppDesignSystem.primary),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  color: AppDesignSystem.danger,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error is String ? error as String : 'Something went wrong',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(retryLabel!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignSystem.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return child ?? const SizedBox.shrink();
  }
}
