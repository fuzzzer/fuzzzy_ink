import 'package:flutter/material.dart';

class FuzzyOverlaySpawner<T> extends StatefulWidget {
  const FuzzyOverlaySpawner({
    super.key,
    required this.spawnedChildBuilder,
    this.onLongPress,
    required this.child,
    this.splashRadius,
    this.splashColor,
    this.offset,
    this.targetAnchor = Alignment.topLeft,
    this.followerAnchor = Alignment.topLeft,
  });

  final Widget Function(BuildContext context, VoidCallback closeOverlay)
      spawnedChildBuilder;
  final void Function()? onLongPress;
  final Widget child;
  final BorderRadius? splashRadius;
  final Color? splashColor;
  final Offset? offset;

  /// Which corner of the child the overlay hangs from, and which corner of
  /// the overlay is pinned there — a right-aligned bubble anchors its pill
  /// at its top-right so the pill grows into the screen, not off it.
  final Alignment targetAnchor;
  final Alignment followerAnchor;

  @override
  State<FuzzyOverlaySpawner<T>> createState() => _FuzzyOverlaySpawnerState<T>();
}

class _FuzzyOverlaySpawnerState<T> extends State<FuzzyOverlaySpawner<T>> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isOverlayVisible = false;

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  void _toggleOverlay() {
    if (_isOverlayVisible) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOverlayVisible = true;
    });
  }

  void _hideOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      setState(() {
        _isOverlayVisible = false;
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideOverlay,
              onPanStart: (_) => _hideOverlay(),
              child: Container(
                color: Colors.transparent,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              offset: widget.offset ?? Offset.zero,
              targetAnchor: widget.targetAnchor,
              followerAnchor: widget.followerAnchor,
              showWhenUnlinked: false,
              child: Material(
                color: Colors.transparent,
                child: widget.spawnedChildBuilder(context, _hideOverlay),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleOverlay,
        onLongPress: widget.onLongPress,
        borderRadius: widget.splashRadius ?? BorderRadius.circular(100),
        splashColor: widget.splashColor,
        child: widget.child,
      ),
    );
  }
}
