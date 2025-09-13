import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class ActiveWorkspace extends StatefulWidget {
  final int currentIndex; // 0..9
  final double workspaceSize;

  const ActiveWorkspace({super.key, required this.currentIndex, this.workspaceSize = 30});

  @override
  State<ActiveWorkspace> createState() => _ActiveWorkspaceState();
}

class _ActiveWorkspaceState extends State<ActiveWorkspace> with TickerProviderStateMixin {
  late AnimationController _headCtrl;
  late AnimationController _tailCtrl;

  double headX = 0;
  double tailX = 0;

  @override
  void initState() {
    super.initState();

    headX = widget.currentIndex * widget.workspaceSize;
    tailX = headX;

    _headCtrl = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() => headX = _headCtrl.value));

    _tailCtrl = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() => tailX = _tailCtrl.value));
  }

  bool _firstBuild = true;

  @override
  void didUpdateWidget(covariant ActiveWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);

    final target = widget.currentIndex * widget.workspaceSize;

    // skip first frame to prevent weird init stretch
    if (_firstBuild) {
      _firstBuild = false;
      headX = tailX = target;
      return;
    }

    _headCtrl.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);

    final spring = SpringDescription(mass: 1, stiffness: 200, damping: 25);
    _tailCtrl.animateWith(SpringSimulation(spring, tailX, target, 0));
  }

  @override
  void dispose() {
    _headCtrl.dispose();
    _tailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: widget.workspaceSize + 4,
      child: Stack(
        children: [
          Positioned(
            left: tailX,
            top: 0,
            child: Container(
              width: (headX - tailX).abs() + (widget.workspaceSize - 4),
              height: widget.workspaceSize - 4,
              margin: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(widget.workspaceSize / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
