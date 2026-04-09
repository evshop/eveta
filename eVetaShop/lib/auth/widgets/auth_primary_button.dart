import 'package:flutter/material.dart';

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Text(label),
    );
  }
}

class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({super.key, required this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      ),
      child: loading
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                  height: 22,
                  width: 22,
                  errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata, size: 24, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(width: 12),
                const Text('Continuar con Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }
}
