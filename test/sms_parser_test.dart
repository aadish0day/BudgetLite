import 'package:flutter_test/flutter_test.dart';
import 'package:budget_lite/core/utils/sms_parser.dart';

void main() {
  group('SmsParser - Real Kotak Bank SMS Samples', () {
    test('Kotak Sample 1: Sent Rs.50.00 to VPA', () {
      const sms = 'Sent Rs.50.00 from Kotak Bank AC X5729 to chaurasiayavijaykumar@oksbi on 08-07-26.UPI Ref 655562388656. Not you, https://kotak.com/KBANKT/Fraud';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 50.00);
      expect(parsed.isIncome, false);
      expect(parsed.date.year, 2026);
      expect(parsed.date.month, 7);
      expect(parsed.date.day, 8);
      expect(parsed.note.toLowerCase(), contains('chaurasiayavijaykumar'));
    });

    test('Kotak Sample 2: Sent Rs.1500.00 to Name', () {
      const sms = 'Sent Rs.1500.00 from XXXXXX5729 to RABITHAKABEERNALAKAN on 08/06/2026. UPI ref no. 652525717686. Not you? Tap https://kotk.in/KOTAKD/FNJ0xJ to report -Kotak';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1500.00);
      expect(parsed.isIncome, false);
      expect(parsed.date.year, 2026);
      expect(parsed.date.month, 6);
      expect(parsed.date.day, 8);
      expect(parsed.note, contains('RABITHAKABEERNALAKAN'));
    });

    test('Kotak Sample 3: Sent Rs.160.00 to Name', () {
      const sms = 'Sent Rs.160.00 from XXXXXX5729 to MATIBUR RAHMAN BORBH on 11/06/2026. UPI ref no. 652811048543. Not you? Tap https://kotk.in/KOTAKD/FRT6IT to report -Kotak';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 160.00);
      expect(parsed.isIncome, false);
      expect(parsed.date.year, 2026);
      expect(parsed.date.month, 6);
      expect(parsed.date.day, 11);
      expect(parsed.note, contains('MATIBUR RAHMAN BORBH'));
    });

    test('Kotak Sample 4: Received Rs.40.00 from VPA', () {
      const sms = 'Received Rs.40.00 in your Kotak Bank AC X5729 from parvati.das27@okicici on 19-05-26.UPI Ref:613922544929.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 40.00);
      expect(parsed.isIncome, true);
      expect(parsed.date.year, 2026);
      expect(parsed.date.month, 5);
      expect(parsed.date.day, 19);
      expect(parsed.note.toLowerCase(), contains('parvati.das27'));
    });

    test('Kotak Sample 5: AutoPay debited towards Spotify', () {
      const sms = 'Your Kotak Bank account has been successfully debited with Rs. 69.00 on 19/05/2026 for UPI AutoPay towards SPOTIFY INDIA PVT LTD. Refer UM no. KBA3d4bb20829cc44769642832b34faf@kotak811. Regards, Kotak Bank';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 69.00);
      expect(parsed.isIncome, false);
      expect(parsed.date.year, 2026);
      expect(parsed.date.month, 5);
      expect(parsed.date.day, 19);
      expect(parsed.note.toLowerCase(), contains('spotify'));
      expect(parsed.categoryId, 'bills');
    });

    test('Kotak Sample 6: Received Rs.390.00 from VPA', () {
      const sms = 'Received Rs.390.00 in your Kotak Bank AC X5729 from parvati.das27@okicici on 05-06-26.UPI Ref:615627994059.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 390.00);
      expect(parsed.isIncome, true);
      expect(parsed.date.year, 2026);
      expect(parsed.date.month, 6);
      expect(parsed.date.day, 5);
      expect(parsed.note.toLowerCase(), contains('parvati.das27'));
    });
  });

  group('SmsParser - 12-hour AM/PM Time Parsing Tests', () {
    test('Converts 02:45 PM -> 14:45:00', () {
      const sms = 'Received Rs. 1500.00 from Dad on 22/07/2026 02:45 PM.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.date.hour, 14);
      expect(parsed.date.minute, 45);
      expect(parsed.date.second, 0);
    });

    test('Converts 2:45PM (no space) -> 14:45:00', () {
      const sms = 'Sent Rs. 350.00 to Starbucks on 22-07-2026 at 2:45PM.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.date.hour, 14);
      expect(parsed.date.minute, 45);
    });

    test('Converts 12:30 AM (Midnight) -> 00:30:00', () {
      const sms = 'Sent Rs. 100.00 on 22-07-2026 at 12:30 AM.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.date.hour, 0);
      expect(parsed.date.minute, 30);
    });

    test('Converts 12:15 PM (Noon) -> 12:15:00', () {
      const sms = 'Sent Rs. 100.00 on 22-07-2026 at 12:15 PM.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.date.hour, 12);
      expect(parsed.date.minute, 15);
    });

    test('Converts 14:30:15 (24-hour format) -> 14:30:15', () {
      const sms = 'Sent Rs. 250.00 to Swiggy on 22-07-26 at 14:30:15.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.date.hour, 14);
      expect(parsed.date.minute, 30);
      expect(parsed.date.second, 15);
    });
  });

  group('SmsParser - Amount Edge Cases', () {
    test('Parses INR 499 without decimal (Netflix)', () {
      const sms = 'Alert: Spent INR 499 on Netflix Recharge at NETFLIX via Netbanking.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 499);
      expect(parsed.isIncome, false);
      expect(parsed.categoryId, 'bills');
    });

    test('Parses Rs 1499 (no space after Rs, no decimal)', () {
      const sms = 'Thank you for using Paytm. Rs 1499 spent at ZARA store on 22-07-2026.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1499);
      expect(parsed.isIncome, false);
      expect(parsed.note.toLowerCase(), contains('zara'));
    });

    test('Parses amount with balance remaining text', () {
      const sms = 'Your card was charged Rs 350.00 at STARBUCKS. Remaining balance Rs 45000.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 350.00);
      expect(parsed.isIncome, false);
      expect(parsed.categoryId, 'food');
    });
  });

  group('SmsParser - Direction Detection Edge Cases', () {
    test('Transferred from is debit', () {
      const sms = 'Rs. 2000.00 transferred from your account to AMAZON on 15-07-2026. UPI Ref: 12345';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isIncome, false);
      expect(parsed.note.toLowerCase(), contains('amazon'));
    });

    test('Added to your is credit', () {
      const sms = 'Rs. 500.00 added to your account from PARENTS on 15-07-2026. UPI Ref: 67890';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isIncome, true);
      expect(parsed.note.toLowerCase(), contains('parents'));
    });

    test('Debit SMS with towards keyword extracts merchant', () {
      const sms = 'Rs. 349.00 debited towards NETFLIX SUBSCRIPTION on 10-06-2026. UPI Ref: 123456';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isIncome, false);
      expect(parsed.note.toLowerCase(), contains('netflix'));
      expect(parsed.categoryId, 'bills');
    });

    test('Debit with towards keyword (AutoPay)', () {
      const sms = 'Your account debited Rs. 69.00 on 19/05/2026 for UPI AutoPay towards SPOTIFY INDIA PVT LTD.';
      final parsed = SmsParser.parseMessage(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 69);
      expect(parsed.isIncome, false);
      expect(parsed.note.toLowerCase(), contains('spotify'));
    });
  });
}
