import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class FuzzySnackBarContent extends StatefulWidget {
  const FuzzySnackBarContent({
    super.key,
    this.overlayEntry,
    required this.snackbarQueue,
    required this.snackbarData,
    this.onDismissed,
  });

  final OverlayEntry? overlayEntry;
  final List<FuzzySnackbarData> snackbarQueue;
  final FuzzySnackbarData snackbarData;
  final void Function()? onDismissed;

  @override
  State<FuzzySnackBarContent> createState() => _SnackBarContentState();
}

const double _borderRadius = 12;

class _SnackBarContentState extends State<FuzzySnackBarContent> {
  bool _isAnimated = true;

  void toggleVisibility() {
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isAnimated = !_isAnimated;
      });
    });
  }

  @override
  void initState() {
    toggleVisibility();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 64.0,
      width: MediaQuery.of(context).size.width,
      child: Dismissible(
        key: const Key('snackbarKey'),
        direction: DismissDirection.up,
        onDismissed: (_) {
          widget.overlayEntry!.remove();
          widget.snackbarQueue.removeAt(0);
          FuzzySnackbar.showNextSnackbar();

          widget.onDismissed?.call();
        },
        child: AnimatedOpacity(
          opacity: _isAnimated ? 1.0 : 0.0,
          duration: widget.snackbarData.duration!,
          curve: Curves.fastOutSlowIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 10,
                  sigmaY: 10,
                ),
                child: Material(
                  elevation: widget.snackbarData.elevation ?? 12.0,
                  shadowColor: fuzzzyColors.focus,
                  child: Container(
                    width: widget.snackbarData.width ?? 200,
                    decoration: BoxDecoration(
                      color: widget.snackbarData.backgroundColor ??
                          fuzzzyColors.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(_borderRadius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          if (widget.snackbarData.leading != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              child: widget.snackbarData.leading,
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.snackbarData.label != null)
                                Text(
                                  widget.snackbarData.label!,
                                  softWrap: true,
                                  textAlign: TextAlign.center,
                                  style: widget.snackbarData.labelStyle ??
                                      fuzzzyTextStyles.body.copyWith(
                                        color: fuzzzyColors.ground,
                                      ),
                                ),
                              Flexible(
                                child: widget.snackbarData.content!,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
