import 'package:flutter/material.dart';

import '../design_system/design_system.dart';

/// Android window size classes, by available logical width (spec §9.3).
enum WindowClass {
  compact,
  medium,
  expanded;

  static WindowClass fromWidth(double width) {
    if (width < 600) return WindowClass.compact;
    if (width < 840) return WindowClass.medium;
    return WindowClass.expanded;
  }

  bool get isCompact => this == WindowClass.compact;
  bool get isExpanded => this == WindowClass.expanded;
  double get gutter => isCompact ? BimbiSpace.md : BimbiSpace.lg;

  /// Readable content width; wider screens get panes, not stretched cards.
  double get maxContentWidth => switch (this) {
    WindowClass.compact => 600,
    WindowClass.medium => 720,
    WindowClass.expanded => 1240,
  };
}

/// Makes the shell's window class available to pages.
class WindowScope extends InheritedWidget {
  const WindowScope({
    super.key,
    required this.windowClass,
    required super.child,
  });
  final WindowClass windowClass;

  static WindowClass of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WindowScope>()?.windowClass ??
      WindowClass.fromWidth(MediaQuery.sizeOf(context).width);

  @override
  bool updateShouldNotify(WindowScope old) => old.windowClass != windowClass;
}

/// Single-column scrolling page body with a constrained readable width.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth});
  final List<Widget> children;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final window = WindowScope.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? window.maxContentWidth,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            window.gutter,
            window.gutter,
            window.gutter,
            BimbiSpace.xxl,
          ),
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: BimbiSpace.md),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Master/detail for expanded windows: two independently scrolling panes.
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 5,
    this.secondaryFlex = 4,
  });

  final List<Widget> primary;
  final List<Widget> secondary;
  final int primaryFlex;
  final int secondaryFlex;

  Widget _pane(BuildContext context, List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(
      BimbiSpace.lg,
      BimbiSpace.lg,
      BimbiSpace.lg,
      BimbiSpace.xxl,
    ),
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: BimbiSpace.md),
        children[i],
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1240),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: primaryFlex, child: _pane(context, primary)),
          Expanded(flex: secondaryFlex, child: _pane(context, secondary)),
        ],
      ),
    ),
  );
}
