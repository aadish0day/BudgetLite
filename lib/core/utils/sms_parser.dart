class ParsedSmsTxn {
  final double amount;
  final String note;
  final String categoryId;
  final DateTime date;
  final String id;
  final DateTime detectedAt;
  final bool isIncome;

  ParsedSmsTxn({
    required this.amount,
    required this.note,
    required this.categoryId,
    required this.date,
    String? id,
    DateTime? detectedAt,
    this.isIncome = false,
  })  : id = id ?? 'sms_${amount}_${note.hashCode}_${date.toIso8601String()}',
        detectedAt = detectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'note': note,
    'categoryId': categoryId,
    'date': date.toIso8601String(),
    'detectedAt': detectedAt.toIso8601String(),
    'isIncome': isIncome,
  };

  factory ParsedSmsTxn.fromJson(Map<String, dynamic> json) => ParsedSmsTxn(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    note: json['note'] as String,
    categoryId: json['categoryId'] as String? ?? 'other',
    date: DateTime.parse(json['date'] as String),
    detectedAt: DateTime.parse(json['detectedAt'] as String),
    isIncome: json['isIncome'] as bool? ?? false,
  );
}

class SmsParser {
  /// Parse a UPI SMS message into a structured transaction.
  ///
  /// [body] - Raw SMS text.
  /// [keywordToCategory] - Optional map of keyword → categoryId from user's
  ///   auto-categorization rules (checked before built-in detection).
  /// [dateOverride] - Optional date override (used when the caller has a
  ///   better date source, e.g. SMS timestamp from the device).
  static ParsedSmsTxn? parseMessage(
    String body, {
    Map<String, String>? keywordToCategory,
    DateTime? dateOverride,
  }) {
    final lowerBody = body.toLowerCase();

    // ── Direction detection ──
    bool isCredit = false;
    bool isDebit = false;

    if (lowerBody.contains('sent rs.') || lowerBody.contains('sent rs ') || lowerBody.contains('sent inr')) {
      isDebit = true;
    } else if (lowerBody.contains('received rs.') || lowerBody.contains('received rs ') || lowerBody.contains('received inr')) {
      isCredit = true;
    } else {
      // Keyword-based detection
      isCredit = lowerBody.contains('credited') ||
          lowerBody.contains('received') ||
          lowerBody.contains('deposited') ||
          lowerBody.contains('refund') ||
          lowerBody.contains('cashback') ||
          lowerBody.contains('added to your') ||
          lowerBody.contains('transferred to your a/c') ||
          lowerBody.contains('transferred to your account');
      isDebit = lowerBody.contains('debit') ||
          lowerBody.contains('debited') ||
          lowerBody.contains('spent') ||
          lowerBody.contains('charged') ||
          lowerBody.contains('paid') ||
          lowerBody.contains('transacted') ||
          lowerBody.contains('withdrawn') ||
          lowerBody.contains('payment of') ||
          lowerBody.contains('transferred from');
    }

    if (!isCredit && !isDebit) return null;

    final isIncome = isCredit && !isDebit;

    // Amount extraction
    double? amount;
    String note = 'Bank transaction';

    final amountMatch = RegExp(
      r'(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(body) ??
    RegExp(
      r'([0-9,]+\.[0-9]+)\s*(?:INR|Rs\.?)',
      caseSensitive: false,
    ).firstMatch(body) ??
    RegExp(
      r'([0-9,]{2,})\s*(?:INR|Rs\.?)(?!\w)',
      caseSensitive: false,
    ).firstMatch(body);
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    }

    if (amount == null || amount <= 0) return null;

    // Merchant / counterparty extraction
    // For Credit (income): sender is after 'from'.
    // For Debit (expense): recipient is after 'to', 'towards', 'at', or 'for'.
    final primaryRegex = isIncome
        ? RegExp(
            r"(?:from)\s+([a-zA-Z0-9\s\.'&,\-@]+?)(?:\s+on\s+\d|\s+at\s+\d|\s+(?:ref|txn|upi|not|refer|regards)[\s:]|(?:\s+\.\s+)|(?:\.\s*$)|$)",
            caseSensitive: false,
          )
        : RegExp(
            r"(?:towards|to|at)\s+([a-zA-Z0-9\s\.'&,\-@]+?)(?:\s+on\s+\d|\s+at\s+\d|\s+(?:ref|txn|upi|not|refer|regards)[\s:]|(?:\s+\.\s+)|(?:\.\s*$)|$)",
            caseSensitive: false,
          );

    var merchantMatch = primaryRegex.firstMatch(body);

    // Fallback if primary preposition wasn't found
    merchantMatch ??= RegExp(
      r"(?:towards|to|from|at)\s+([a-zA-Z0-9\s\.'&,\-@]+?)(?:\s+on\s+\d|\s+at\s+\d|\s+(?:ref|txn|upi|not|refer|regards)[\s:]|(?:\s+\.\s+)|(?:\.\s*$)|$)",
      caseSensitive: false,
    ).firstMatch(body);

    if (merchantMatch != null) {
      final rawNote = merchantMatch.group(1)!.trim();
      if (rawNote.isNotEmpty && rawNote.length < 60) {
        note = rawNote;
      }
    }

    // Clean up note if it contains generic wallet app names
    if (note.toLowerCase().contains('gpay') ||
        note.toLowerCase().contains('google pay') ||
        note.toLowerCase().contains('phonepe') ||
        note.toLowerCase().contains('paytm')) {
      final parts = note.split(RegExp(r'\s+'));
      note = parts.where((p) => !p.toLowerCase().contains('pay') && !p.toLowerCase().contains('gpay') && !p.toLowerCase().contains('phonepe')).join(' ');
      if (note.trim().isEmpty) note = 'UPI transaction';
    }

    // Auto-detect category: user rules first, then built-in detection
    String categoryId = 'other';
    bool userRuleMatched = false;
    if (keywordToCategory != null && keywordToCategory.isNotEmpty) {
      for (final entry in keywordToCategory.entries) {
        if (note.toLowerCase().contains(entry.key)) {
          categoryId = entry.value;
          userRuleMatched = true;
          break;
        }
      }
    }
    if (!userRuleMatched) {
      categoryId = _detectCategoryFromMerchant(note);
    }

    // Income defaults to 'income' only when no user rule matched
    if (isIncome && !userRuleMatched) {
      categoryId = 'income';
    }

    // Parse date & time from SMS body, falling back to override or now
    final parsedDate = dateOverride ?? _extractDate(body) ?? DateTime.now();

    return ParsedSmsTxn(
      amount: amount,
      note: note.trim().isNotEmpty ? note.trim() : 'Bank transaction',
      categoryId: categoryId,
      date: parsedDate,
      isIncome: isIncome,
    );
  }

  /// Extract a transaction date and time from an SMS body.
  /// Supports:
  /// - Dates: DD/MM/YYYY, DD-MM-YYYY, DD/MM/YY, DD-MM-YY, DD Mon YYYY, YYYY-MM-DD.
  /// - Times: HH:MM:SS, HH:MM, HH:MM AM/PM.
  static DateTime? _extractDate(String body) {
    // Extract optional time (e.g. 14:30:15 or 02:15 PM or 2:15PM)
    int hour = 0;
    int minute = 0;
    int second = 0;

    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false).firstMatch(body);
    if (timeMatch != null) {
      hour = int.parse(timeMatch.group(1)!);
      minute = int.parse(timeMatch.group(2)!);
      if (timeMatch.group(3) != null) {
        second = int.parse(timeMatch.group(3)!);
      }
      final ampm = timeMatch.group(4)?.toLowerCase();
      if (ampm == 'pm' && hour < 12) {
        hour += 12;
      } else if (ampm == 'am' && hour == 12) {
        hour = 0;
      }
    }

    // DD/MM/YYYY or DD-MM-YYYY or DD/MM/YY or DD-MM-YY
    final dmy = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(body);
    if (dmy != null) {
      final day = int.parse(dmy.group(1)!);
      final month = int.parse(dmy.group(2)!);
      var year = int.parse(dmy.group(3)!);
      if (year < 100) {
        year += 2000;
      }
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

    // DD Mon YYYY or DD Mon YY (e.g. "22 Jul 2026", "22 Jul 26")
    final dMonY = RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{2,4})', caseSensitive: false).firstMatch(body);
    if (dMonY != null) {
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final month = months[dMonY.group(2)!.toLowerCase().substring(0, 3)];
      final day = int.parse(dMonY.group(1)!);
      var year = int.parse(dMonY.group(3)!);
      if (year < 100) year += 2000;
      if (month != null && day >= 1 && day <= 31) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

    // YYYY-MM-DD
    final ymd = RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})').firstMatch(body);
    if (ymd != null) {
      return DateTime(
        int.parse(ymd.group(1)!),
        int.parse(ymd.group(2)!),
        int.parse(ymd.group(3)!),
        hour,
        minute,
        second,
      );
    }

    return null;
  }

  static String _detectCategoryFromMerchant(String note) {
    final cleanNote = note.toLowerCase();

    if (cleanNote.contains('starbucks') || cleanNote.contains('swiggy') ||
        cleanNote.contains('zomato') || cleanNote.contains('restaurant') ||
        cleanNote.contains('cafe') || cleanNote.contains('food') ||
        cleanNote.contains('mcdonalds') || cleanNote.contains('kfc') ||
        cleanNote.contains('diner') || cleanNote.contains('baker') ||
        cleanNote.contains('pizza') || cleanNote.contains('burger') ||
        cleanNote.contains('domino') || cleanNote.contains('subway') ||
        cleanNote.contains('dhaba')) {
      return 'food';
    }

    if (cleanNote.contains('uber') || cleanNote.contains('ola') ||
        cleanNote.contains('metro') || cleanNote.contains('petrol') ||
        cleanNote.contains('fuel') || cleanNote.contains('shell') ||
        cleanNote.contains('railway') || cleanNote.contains('taxi') ||
        cleanNote.contains('irctc') || cleanNote.contains('bus')) {
      return 'transport';
    }

    if (cleanNote.contains('amazon') || cleanNote.contains('flipkart') ||
        cleanNote.contains('myntra') || cleanNote.contains('shopping') ||
        cleanNote.contains('zara') || cleanNote.contains('groceries') ||
        cleanNote.contains('supermarket') || cleanNote.contains('store') ||
        cleanNote.contains('mart') || cleanNote.contains('ajio') ||
        cleanNote.contains('nykaa') || cleanNote.contains('h&m')) {
      return 'shopping';
    }

    if (cleanNote.contains('bill') || cleanNote.contains('electricity') ||
        cleanNote.contains('broadband') || cleanNote.contains('recharge') ||
        cleanNote.contains('water') || cleanNote.contains('gas') ||
        cleanNote.contains('insurance') || cleanNote.contains('bsnl') ||
        cleanNote.contains('jio') || cleanNote.contains('airtel') ||
        cleanNote.contains('netflix') || cleanNote.contains('spotify')) {
      return 'bills';
    }

    if (cleanNote.contains('pvr') || cleanNote.contains('bookmyshow') ||
        cleanNote.contains('steam') || cleanNote.contains('movie') ||
        cleanNote.contains('cinema')) {
      return 'entertainment';
    }

    return 'other';
  }
}
