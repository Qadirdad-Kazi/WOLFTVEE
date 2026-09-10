import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/wolf_tv.dart';
import '../theme/wolf_colors.dart';

/// Wraps a control with D-pad / remote focus chrome **only on TV**.
///
/// On Android phone, macOS, and Windows this is a no-op passthrough so those
/// platforms never get Fire Stick-style focus rings. Mouse clicks and taps
/// still work everywhere via the child's own [onTap] / [InkWell].
class WolfTvFocusable extends StatefulWidget {
  const WolfTvFocusable({
    super.key,
    required this.child,
    this.onActivate,
    this.autofocus = false,
    this.enabled = true,
  });

  final Widget child;

  /// Fired on remote Select / Enter / Center (ActivateIntent).
  final VoidCallback? onActivate;

  final bool autofocus;
  final bool enabled;

  @override
  State<WolfTvFocusable> createState() => _WolfTvFocusableState();
}

class _WolfTvFocusableState extends State<WolfTvFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    if (!WolfTv.isTv || !widget.enabled) {
      return widget.child;
    }

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (show) {
        setState(() => _focused = show);
        if (show) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 220),
              alignment: 0.35,
              curve: Curves.easeOutCubic,
            );
          });
        }
      },
      actions: <Type, Action<Intent>>{
        if (widget.onActivate != null)
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onActivate!();
              return null;
            },
          ),
      },
      child: AnimatedScale(
        scale: _focused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            border: Border.all(
              color: _focused ? WolfColors.lime : Colors.transparent,
              width: 3,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: WolfColors.lime.withValues(alpha: 0.4),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// App-level shortcuts so Fire remote Select / Enter activate focused widgets.
class WolfTvShortcuts extends StatelessWidget {
  const WolfTvShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!WolfTv.isTv) return child;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: child,
      ),
    );
  }
}
