import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Debt Projection & Payoff Calculator Tests', () {
    test('Calculates payoff months with monthly payment exceeding interest', () {
      double principal = 10000;
      double annualRate = 12; // 12% per year -> 1% per month
      double monthlyPayment = 1000;

      int months = 0;
      double totalInterest = 0;
      double monthlyRate = annualRate / 100 / 12;

      while (principal > 0 && months < 360) {
        double interest = principal * monthlyRate;
        totalInterest += interest;
        principal += interest;
        principal -= monthlyPayment;
        months++;
      }

      expect(months, equals(11));
      expect(totalInterest, greaterThan(0));
    });

    test('Identifies infinite payoff when monthly payment is below interest', () {
      double principal = 10000;
      double annualRate = 12; // $100 monthly interest
      double monthlyPayment = 50; // less than interest

      double monthlyRate = annualRate / 100 / 12;
      double monthlyInterest = principal * monthlyRate;

      expect(monthlyPayment <= monthlyInterest, isTrue);
    });
  });
}
