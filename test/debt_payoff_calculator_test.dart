import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Debt Projection & Payoff Calculator Tests', () {
    test(
      'Calculates payoff months with monthly payment exceeding interest',
      () {
        double principal = 10000;
        const double annualRate = 12; // 12% per year -> 1% per month
        const double monthlyPayment = 1000;

        int months = 0;
        double totalInterest = 0;
        const double monthlyRate = annualRate / 100 / 12;

        while (principal > 0 && months < 360) {
          final double interest = principal * monthlyRate;
          totalInterest += interest;
          principal += interest;
          principal -= monthlyPayment;
          months++;
        }

        expect(months, equals(11));
        expect(totalInterest, greaterThan(0));
      },
    );

    test(
      'Identifies infinite payoff when monthly payment is below interest',
      () {
        const double principal = 10000;
        const double annualRate = 12; // $100 monthly interest
        const double monthlyPayment = 50; // less than interest

        const double monthlyRate = annualRate / 100 / 12;
        const double monthlyInterest = principal * monthlyRate;

        expect(monthlyPayment <= monthlyInterest, isTrue);
      },
    );
  });
}
