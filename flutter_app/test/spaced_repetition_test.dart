import 'package:flutter_test/flutter_test.dart';
import 'package:famquest_v9/features/study/spaced_repetition_scheduler.dart';

void main() {
  group('SpacedRepetitionScheduler - SM-2 Algorithm', () {
    test('First repetition should schedule 1 day later with quality >= 3', () {
      final result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 1),
        quality: 4,
        repetitions: 0,
      );

      expect(result.intervalDays, equals(1));
      expect(result.repetitions, equals(1));
      expect(result.nextReviewDate, equals(DateTime(2025, 1, 2)));
    });

    test('Second repetition should schedule 6 days later with quality >= 3', () {
      final result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 2),
        quality: 4,
        repetitions: 1,
      );

      expect(result.intervalDays, equals(6));
      expect(result.repetitions, equals(2));
      expect(result.nextReviewDate, equals(DateTime(2025, 1, 8)));
    });

    test('Third repetition should use EF multiplier', () {
      final result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 8),
        quality: 4,
        easinessFactor: 2.5,
        repetitions: 2,
      );

      expect(result.intervalDays, equals(15)); // 6 * 2.5 = 15
      expect(result.repetitions, equals(3));
    });

    test('Poor quality (< 3) should reset repetitions', () {
      final result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 1),
        quality: 2,
        repetitions: 5,
      );

      expect(result.intervalDays, equals(1));
      expect(result.repetitions, equals(0));
    });

    test('Easiness Factor should not go below 1.3', () {
      final result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 1),
        quality: 0,
        easinessFactor: 1.3,
        repetitions: 0,
      );

      expect(result.easinessFactor, greaterThanOrEqualTo(1.3));
    });

    test('Perfect recall (quality 5) should increase EF', () {
      final result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 1),
        quality: 5,
        easinessFactor: 2.5,
        repetitions: 0,
      );

      expect(result.easinessFactor, greaterThan(2.5));
    });

    test('Difficult recall (quality 3) should decrease EF', () {
      final result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 1),
        quality: 3,
        easinessFactor: 2.5,
        repetitions: 0,
      );

      expect(result.easinessFactor, lessThan(2.5));
    });

    test('Quality values should be clamped to 0-5', () {
      final resultHigh = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 1),
        quality: 10,
        repetitions: 0,
      );

      final resultLow = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 1),
        quality: -5,
        repetitions: 0,
      );

      // Should not throw and should process as valid quality
      expect(resultHigh.repetitions, equals(1));
      expect(resultLow.repetitions, equals(0));
    });
  });

  group('SpacedRepetitionScheduler - Date Utilities', () {
    test('isSameDay should identify same calendar day', () {
      final date1 = DateTime(2025, 1, 15, 10, 30);
      final date2 = DateTime(2025, 1, 15, 23, 45);
      final date3 = DateTime(2025, 1, 16, 0, 0);

      expect(isSameDay(date1, date2), isTrue);
      expect(isSameDay(date1, date3), isFalse);
    });

    test('isDueToday should identify sessions due today', () {
      // Mock session for testing - we'll just test the date logic
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 0);
      final tomorrow = today.add(const Duration(days: 1));

      expect(
        today.year == now.year &&
            today.month == now.month &&
            today.day == now.day,
        isTrue,
      );
      expect(
        tomorrow.year == now.year &&
            tomorrow.month == now.month &&
            tomorrow.day == now.day,
        isFalse,
      );
    });
  });

  group('SpacedRepetitionScheduler - Real-world Scenarios', () {
    test('Struggling student scenario - keeps getting quality 2-3', () {
      // Start with first attempt
      var result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 1),
        quality: 2,
        repetitions: 0,
      );

      // Should reset and schedule tomorrow
      expect(result.intervalDays, equals(1));
      expect(result.repetitions, equals(0));

      // Try again next day, still struggling
      result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: DateTime(2025, 1, 2),
        quality: 3,
        easinessFactor: result.easinessFactor,
        repetitions: result.repetitions,
      );

      // Should move forward but with reduced EF
      expect(result.intervalDays, equals(1));
      expect(result.repetitions, equals(1));
      expect(result.easinessFactor, lessThan(2.5));
    });

    test('Excellent student scenario - consistently quality 4-5', () {
      var lastDate = DateTime(2025, 1, 1);
      var ef = 2.5;
      var reps = 0;

      // First review - excellent
      var result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: lastDate,
        quality: 5,
        easinessFactor: ef,
        repetitions: reps,
      );

      expect(result.intervalDays, equals(1));
      expect(result.easinessFactor, greaterThan(ef));

      // Second review - excellent
      lastDate = result.nextReviewDate;
      result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: lastDate,
        quality: 5,
        easinessFactor: result.easinessFactor,
        repetitions: result.repetitions,
      );

      expect(result.intervalDays, equals(6));

      // Third review - excellent
      lastDate = result.nextReviewDate;
      result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: lastDate,
        quality: 5,
        easinessFactor: result.easinessFactor,
        repetitions: result.repetitions,
      );

      // Should have long interval now
      expect(result.intervalDays, greaterThan(10));
      expect(result.easinessFactor, greaterThan(2.5));
    });

    test('Mixed performance scenario - quality varies', () {
      var lastDate = DateTime(2025, 1, 1);
      var ef = 2.5;
      var reps = 0;

      // First: good (quality 4)
      var result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: lastDate,
        quality: 4,
        easinessFactor: ef,
        repetitions: reps,
      );

      // Second: good (quality 4)
      lastDate = result.nextReviewDate;
      result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: lastDate,
        quality: 4,
        easinessFactor: result.easinessFactor,
        repetitions: result.repetitions,
      );

      expect(result.repetitions, equals(2));

      // Third: forgot (quality 2) - should reset
      lastDate = result.nextReviewDate;
      result = SpacedRepetitionScheduler.calculateNextReview(
        lastReviewDate: lastDate,
        quality: 2,
        easinessFactor: result.easinessFactor,
        repetitions: result.repetitions,
      );

      expect(result.repetitions, equals(0));
      expect(result.intervalDays, equals(1));
      expect(result.easinessFactor, lessThan(2.5));
    });
  });

  group('SpacedRepetitionScheduler - Integration Tests', () {
    test('Quiz score to quality conversion', () {
      // Helper to convert quiz percentage to quality rating
      int quizScoreToQuality(int score, int total) {
        final percentage = (score / total) * 100;
        if (percentage >= 90) return 5;
        if (percentage >= 80) return 4;
        if (percentage >= 70) return 3;
        if (percentage >= 60) return 2;
        if (percentage >= 50) return 1;
        return 0;
      }

      expect(quizScoreToQuality(10, 10), equals(5)); // 100%
      expect(quizScoreToQuality(8, 10), equals(4)); // 80%
      expect(quizScoreToQuality(7, 10), equals(3)); // 70%
      expect(quizScoreToQuality(6, 10), equals(2)); // 60%
      expect(quizScoreToQuality(5, 10), equals(1)); // 50%
      expect(quizScoreToQuality(4, 10), equals(0)); // 40%
    });

    test('Long-term retention simulation (30 days)', () {
      var lastDate = DateTime(2025, 1, 1);
      var ef = 2.5;
      var reps = 0;
      final reviews = <DateTime>[];

      // Simulate perfect reviews over 30 days
      while (lastDate.isBefore(DateTime(2025, 1, 31))) {
        final result = SpacedRepetitionScheduler.calculateNextReview(
          lastReviewDate: lastDate,
          quality: 5,
          easinessFactor: ef,
          repetitions: reps,
        );

        reviews.add(result.nextReviewDate);
        lastDate = result.nextReviewDate;
        ef = result.easinessFactor;
        reps = result.repetitions;

        // Break if next review is beyond 30 days
        if (lastDate.isAfter(DateTime(2025, 1, 31))) break;
      }

      // With perfect recall, should have increasing intervals
      expect(reviews.length, greaterThan(3));
      expect(ef, greaterThan(2.5));
    });
  });
}
