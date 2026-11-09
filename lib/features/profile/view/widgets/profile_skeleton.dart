import 'package:flutter/material.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/widgets/desk_background.dart';
import '../../../../ui/widgets/paper_card.dart';

/// Loading skeleton for the Profile screen that renders a pulsing placeholder
/// matching the exact layout of the loaded profile.
class ProfileSkeleton extends StatefulWidget {
  const ProfileSkeleton({super.key});

  @override
  State<ProfileSkeleton> createState() => _ProfileSkeletonState();
}

class _ProfileSkeletonState extends State<ProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildSkeletonBox({
    required InkTokens tokens,
    double? width,
    required double height,
    double borderRadius = 8,
    BoxShape shape = BoxShape.rectangle,
  }) {
    final baseColor = tokens.isDark ? Colors.white : Colors.black;
    final minAlpha = tokens.isDark ? 0.05 : 0.04;
    final maxAlpha = tokens.isDark ? 0.16 : 0.12;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final currentAlpha =
            minAlpha + (maxAlpha - minAlpha) * _pulseAnimation.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: baseColor.withOpacity(currentAlpha),
            shape: shape,
            borderRadius: shape == BoxShape.rectangle
                ? BorderRadius.circular(borderRadius)
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Stack (Banner + Avatar)
          SizedBox(
            height: 180 + 48,
            child: Stack(
              children: [
                const SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: DeskBackground(),
                ),
                Positioned(
                  top: 180 - 48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.paper,
                        border: Border.all(color: tokens.paper, width: 4),
                      ),
                      child: _buildSkeletonBox(
                        tokens: tokens,
                        width: 96,
                        height: 96,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: InkSpacing.s12),

          // 2. Name and Email
          Center(
            child: Column(
              children: [
                _buildSkeletonBox(
                  tokens: tokens,
                  width: 160,
                  height: 22,
                  borderRadius: 6,
                ),
                const SizedBox(height: InkSpacing.s8),
                _buildSkeletonBox(
                  tokens: tokens,
                  width: 200,
                  height: 14,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: InkSpacing.s16),

          // 3. Profile Stats (Boards, Friends, Status)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16),
            child: Row(
              children: [
                Expanded(
                  child: PaperCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: InkSpacing.s8,
                      vertical: InkSpacing.s12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSkeletonBox(
                          tokens: tokens,
                          width: 36,
                          height: 20,
                          borderRadius: 4,
                        ),
                        const SizedBox(height: 6),
                        _buildSkeletonBox(
                          tokens: tokens,
                          width: 48,
                          height: 12,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: InkSpacing.s12),
                Expanded(
                  child: PaperCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: InkSpacing.s8,
                      vertical: InkSpacing.s12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSkeletonBox(
                          tokens: tokens,
                          width: 36,
                          height: 20,
                          borderRadius: 4,
                        ),
                        const SizedBox(height: 6),
                        _buildSkeletonBox(
                          tokens: tokens,
                          width: 48,
                          height: 12,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: InkSpacing.s12),
                Expanded(
                  child: PaperCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: InkSpacing.s8,
                      vertical: InkSpacing.s12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSkeletonBox(
                          tokens: tokens,
                          width: 50,
                          height: 20,
                          borderRadius: 4,
                        ),
                        const SizedBox(height: 6),
                        _buildSkeletonBox(
                          tokens: tokens,
                          width: 40,
                          height: 12,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: InkSpacing.s12),

          // 4. Joined Date Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s24),
            child: Row(
              children: [
                _buildSkeletonBox(
                  tokens: tokens,
                  width: 14,
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(width: 6),
                _buildSkeletonBox(
                  tokens: tokens,
                  width: 110,
                  height: 12,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: InkSpacing.s12),

          // 5. Bio Section Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s24),
            child: PaperCard(
              padding: const EdgeInsets.all(InkSpacing.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonBox(
                    tokens: tokens,
                    width: 36,
                    height: 14,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: InkSpacing.s12),
                  _buildSkeletonBox(
                    tokens: tokens,
                    width: double.infinity,
                    height: 13,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: InkSpacing.s8),
                  _buildSkeletonBox(
                    tokens: tokens,
                    width: 240,
                    height: 13,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: InkSpacing.s32),

          // 6. Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s24),
            child: Row(
              children: [
                Expanded(
                  child: _buildSkeletonBox(
                    tokens: tokens,
                    height: 44,
                    borderRadius: 12,
                  ),
                ),
                const SizedBox(width: InkSpacing.s12),
                Expanded(
                  child: _buildSkeletonBox(
                    tokens: tokens,
                    height: 44,
                    borderRadius: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: InkSpacing.s32 + 8),
        ],
      ),
    );
  }
}
