import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Màn giữ chỗ cho route chưa làm. Agent thay bằng màn thật trong `<f>_routes.dart`.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, this.detail});

  final String title;

  /// Thông tin phụ (vd. path nhận được qua `extra`).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 64),
              const SizedBox(height: 12),
              Text(
                context.l10n.core_comingSoon,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
