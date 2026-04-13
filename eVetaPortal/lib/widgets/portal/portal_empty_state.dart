import 'package:flutter/material.dart';

import 'portal_tokens.dart';

class PortalEmptyState extends StatelessWidget {
  const PortalEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PortalTokens.space3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(PortalTokens.radius2xl),
              ),
              child: Icon(icon, size: 48, color: scheme.primary.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: PortalTokens.space3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: PortalTokens.space1),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: PortalTokens.space3),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
