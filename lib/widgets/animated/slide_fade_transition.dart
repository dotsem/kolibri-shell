import 'package:flutter/material.dart';

enum SlideDirection { left, right, up, down }

class SlideFadeTransition extends StatefulWidget {
  final Widget child;
  final bool visible;
  final Duration duration;
  final SlideDirection direction;

  const SlideFadeTransition({super.key, required this.child, required this.visible, this.duration = const Duration(milliseconds: 300), this.direction = SlideDirection.up});

  @override
  State<SlideFadeTransition> createState() => _SlideFadeTransitionState();
}

class _SlideFadeTransitionState extends State<SlideFadeTransition> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  Offset _getBeginOffset() {
    switch (widget.direction) {
      case SlideDirection.left:
        return const Offset(-0.2, 0);
      case SlideDirection.right:
        return const Offset(0.2, 0);
      case SlideDirection.up:
        return const Offset(0, -0.2);
      case SlideDirection.down:
        return const Offset(0, 0.2);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _slide = Tween<Offset>(begin: _getBeginOffset(), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    if (widget.visible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SlideFadeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
