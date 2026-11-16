import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/navigation/back_exit_policy.dart';

void main() {
  group('BackExitPolicy', () {
    test('first back press never exits', () {
      final policy = BackExitPolicy();
      expect(policy.shouldExit(DateTime(2026, 1, 1, 12)), isFalse);
    });

    test('second press within five seconds exits', () {
      final policy = BackExitPolicy();
      final first = DateTime(2026, 1, 1, 12);
      policy.shouldExit(first);
      expect(
        policy.shouldExit(first.add(const Duration(seconds: 4))),
        isTrue,
      );
    });

    test('second press exactly at the window boundary exits', () {
      final policy = BackExitPolicy();
      final first = DateTime(2026, 1, 1, 12);
      policy.shouldExit(first);
      expect(
        policy.shouldExit(first.add(const Duration(seconds: 5))),
        isTrue,
      );
    });

    test('press after the window only restarts the timer', () {
      final policy = BackExitPolicy();
      final first = DateTime(2026, 1, 1, 12);
      final tooLate = first.add(const Duration(seconds: 6));
      policy.shouldExit(first);
      expect(policy.shouldExit(tooLate), isFalse);
      expect(
        policy.shouldExit(tooLate.add(const Duration(seconds: 2))),
        isTrue,
      );
    });

    test('reset forgets a pending first press', () {
      final policy = BackExitPolicy();
      final first = DateTime(2026, 1, 1, 12);
      policy.shouldExit(first);
      policy.reset();
      expect(
        policy.shouldExit(first.add(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('hint text tells the user to press back again', () {
      expect(BackExitPolicy.exitHint.toLowerCase(), contains('press back again'));
    });
  });
}
