import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/profile/view/widgets/profile_skeleton.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:inklink/ui/widgets/paper_card.dart';

void main() {
  Widget buildTestWidget({bool isDark = false}) {
    return MaterialApp(
      theme: isDark ? InkTheme.dark() : InkTheme.light(),
      home: const Scaffold(
        body: ProfileSkeleton(),
      ),
    );
  }

  testWidgets('ProfileSkeleton renders with pulsing animation in light mode', (tester) async {
    await tester.pumpWidget(buildTestWidget(isDark: false));

    // Verify skeleton elements are present
    expect(find.byType(ProfileSkeleton), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(PaperCard), findsNWidgets(4)); // 3 stat cards + 1 bio card

    // Initial pump and animation step
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('ProfileSkeleton renders with pulsing animation in dark mode', (tester) async {
    await tester.pumpWidget(buildTestWidget(isDark: true));

    expect(find.byType(ProfileSkeleton), findsOneWidget);
    expect(find.byType(PaperCard), findsNWidgets(4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);
  });
}
