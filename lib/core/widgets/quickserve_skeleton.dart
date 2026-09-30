import 'package:flutter/material.dart';

/// Reusable skeleton shimmer loader widget for modern UI state placeholders.
class QuickServeSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const QuickServeSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  factory QuickServeSkeleton.card({
    Key? key,
    double height = 120,
    double borderRadius = 16,
  }) =>
      QuickServeSkeleton(
        key: key,
        width: double.infinity,
        height: height,
        borderRadius: borderRadius,
      );

  factory QuickServeSkeleton.avatar({
    Key? key,
    double size = 48,
  }) =>
      QuickServeSkeleton(
        key: key,
        width: size,
        height: size,
        borderRadius: size / 2,
      );

  @override
  State<QuickServeSkeleton> createState() => _QuickServeSkeletonState();
}

class _QuickServeSkeletonState extends State<QuickServeSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton placeholder list for loading dashboards & feeds
class QuickServeSkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const QuickServeSkeletonList({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 110,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => QuickServeSkeleton.card(height: itemHeight),
    );
  }
}
