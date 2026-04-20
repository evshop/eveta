import 'package:flutter/material.dart';

enum PortalNoticeType { info, success, error }

void showPortalNotice(
  BuildContext context,
  String message, {
  PortalNoticeType type = PortalNoticeType.info,
}) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final (Color bg, Color fg, IconData icon) = switch (type) {
    PortalNoticeType.success => (
        isDark ? const Color(0xFF173B2A) : const Color(0xFFE8F7EF),
        isDark ? const Color(0xFFA7F0C5) : const Color(0xFF0E8B53),
        Icons.check_circle_rounded,
      ),
    PortalNoticeType.error => (
        isDark ? const Color(0xFF3D1C22) : const Color(0xFFFCEBEC),
        isDark ? const Color(0xFFF4B0B7) : const Color(0xFFBA2D3C),
        Icons.error_rounded,
      ),
    PortalNoticeType.info => (
        isDark ? const Color(0xFF1D2634) : const Color(0xFFEAF2FF),
        isDark ? const Color(0xFFB8D1FF) : const Color(0xFF245FC8),
        Icons.info_rounded,
      ),
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.28)),
      ),
      content: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
