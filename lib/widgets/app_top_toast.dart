import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

enum AppToastType { info, success, error }

class AppTopToast {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _timer?.cancel();
    _currentEntry?.remove();

    final colors = switch (type) {
      AppToastType.success => (
          icon: Icons.check_circle_rounded,
          fg: const Color(0xFF087A45),
          bg: const Color(0xFFEAF8F1),
        ),
      AppToastType.error => (
          icon: Icons.error_rounded,
          fg: const Color(0xFFC82E2E),
          bg: const Color(0xFFFFEEEE),
        ),
      AppToastType.info => (
          icon: Icons.info_rounded,
          fg: Colors.black,
          bg: Colors.white,
        ),
    };

    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 18,
        right: 18,
        child: _ToastBody(
          message: message,
          icon: colors.icon,
          foreground: colors.fg,
          background: colors.bg,
        ),
      ),
    );

    overlay.insert(_currentEntry!);
    _timer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _ToastBody extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color foreground;
  final Color background;

  const _ToastBody({
    required this.message,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: background.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: foreground, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
