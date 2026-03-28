import 'package:flutter/material.dart';

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final target = width < maxWidth ? width : maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: target, child: child),
        );
      },
    );
  }
}
