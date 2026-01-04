import 'package:flutter/material.dart';

class CustomSpeedDial extends StatefulWidget {
  final List<SpeedDialChild> children;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final IconData? closeIcon;

  const CustomSpeedDial({
    super.key,
    required this.children,
    this.backgroundColor = Colors.blue,
    this.foregroundColor = Colors.white,
    this.icon = Icons.add,
    this.closeIcon,
  });

  @override
  State<CustomSpeedDial> createState() => _CustomSpeedDialState();
}

class _CustomSpeedDialState extends State<CustomSpeedDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Background overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: _controller.isCompleted ? _toggle : null,
            child: AnimatedOpacity(
              opacity: _controller.isCompleted ? 0.4 : 0,
              duration: const Duration(milliseconds: 300),
              child: Container(color: Colors.black),
            ),
          ),
        ),
        
        // Speed dial children
        ..._buildChildren(),
        
        // Main FAB
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: widget.backgroundColor,
            foregroundColor: widget.foregroundColor,
            onPressed: _toggle,
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _animation,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChildren() {
    return List<Widget>.generate(
      widget.children.length,
      (index) {
        final child = widget.children[index];
        final position = (widget.children.length - index) * 60.0;
        
        return Positioned(
          bottom: 16 + position,
          right: 16,
          child: ScaleTransition(
            scale: _animation,
            child: FadeTransition(
              opacity: _animation,
              child: FloatingActionButton(
                heroTag: 'speed-dial-child-$index',
                mini: true,
                backgroundColor: child.backgroundColor ?? widget.backgroundColor,
                foregroundColor: child.foregroundColor ?? widget.foregroundColor,
                onPressed: () {
                  _toggle();
                  child.onTap?.call();
                },
                child: Icon(child.icon),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SpeedDialChild {
  final IconData icon;
  final String? label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onTap;

  SpeedDialChild({
    required this.icon,
    this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
  });
}