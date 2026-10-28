import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Wraps a card/row so it works with Android TV remotes: D-pad focus shows a
/// glow, and Select/Enter/Space activates it. Mouse and touch taps still work.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.onTap,
    required this.child,
    this.autofocus = false,
    this.borderRadius = 16,
    this.semanticLabel,
  });

  final VoidCallback onTap;
  final Widget child;
  final bool autofocus;
  final double borderRadius;
  final String? semanticLabel;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  static final _activateKeyIds = {
    LogicalKeyboardKey.select.keyId,
    LogicalKeyboardKey.enter.keyId,
    LogicalKeyboardKey.numpadEnter.keyId,
    LogicalKeyboardKey.space.keyId,
    LogicalKeyboardKey.gameButtonA.keyId,
  };

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: true,
        skipTraversal: false,
        debugLabel: 'tv-focusable',
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              _activateKeyIds.contains(event.logicalKey.keyId)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _focusNode.requestFocus(),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: 0.55),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
                border: Border.all(
                  color: _focused ? AppColors.cyan : Colors.transparent,
                  width: 2,
                ),
              ),
              transform: _focused
                  ? Matrix4.diagonal3Values(1.03, 1.03, 1)
                  : Matrix4.identity(),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
