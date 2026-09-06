class ParsedSmsTxn {
  ParsedSmsTxn({
    required this.amount,
    required this.note,
    required this.categoryId,
    required this.date,
    String? id,
    DateTime? detectedAt,
    this.isIncome = false,
    this.payee,
  }) : id =
           id ??
           'sms_${amount}_${(payee ?? note).replaceAll(RegExp('[^a-zA-Z0-9]'), '').toLowerCase()}_${date.millisecondsSinceEpoch}',
       detectedAt = detectedAt ?? DateTime.now();

  factory ParsedSmsTxn.fromJson(Map<String, dynamic> json) => ParsedSmsTxn(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    note: json['note'] as String? ?? '',
    categoryId: json['categoryId'] as String? ?? 'other',
    date: DateTime.parse(json['date'] as String),
    detectedAt: DateTime.parse(json['detectedAt'] as String),
    isIncome: json['isIncome'] as bool? ?? false,
    payee: json['payee'] as String?,
  );
  final double amount;
  final String note;
  final String categoryId;
  final DateTime date;
  final String id;
  final DateTime detectedAt;
  final bool isIncome;
  final String? payee;

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'note': note,
    'categoryId': categoryId,
    'date': date.toIso8601String(),
    'detectedAt': detectedAt.toIso8601String(),
    'isIncome': isIncome,
    'payee': payee,
  };
}

class SmsParser {
  /// Parse a UPI SMS message into a structured transaction.
  static ParsedSmsTxn? parse(
    String body, {
    Map<String, String>? keywordToCategory,
    DateTime? dateOverride,
    bool includeMerchantNote = false,
  }) => parseMessage(
    body,
    keywordToCategory: keywordToCategory,
    dateOverride: dateOverride,
    includeMerchantNote: includeMerchantNote,
  );

  static String _sanitizeFraudWarnings(String text) {
    return text
        .replaceAll(
          RegExp(
            r'(?:call|sms|dial|contact|report|forward|tap|visit|help)\b[^.\n]*(?:unauthorized|fraud|not you)[^.\n]*[.\n]?',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:if\s+(?:this\s+is\s+)?unauthorized|in\s+case\s+of\s+unauthorized)[^.\n]*[.\n]?',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:if\s+not\s+(?:done\s+by\s+)?you|not\s+you\??)[^.\n]*[.\n]?',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'to\s+report\s+(?:unauthorized|fraud)[^.\n]*[.\n]?',
            caseSensitive: false,
          ),
          ' ',
        );
  }

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
    bool includeMerchantNote = false,
  }) {
    final cleanBody = _sanitizeFraudWarnings(body);
    final lowerCleanBody = cleanBody.toLowerCase();

    // ── Direction detection ──
    final hasCreditKeyword =
        lowerCleanBody.contains('credited') ||
        lowerCleanBody.contains('refund') ||
        lowerCleanBody.contains('cashback') ||
        lowerCleanBody.contains('received rs.') ||
        lowerCleanBody.contains('received rs ') ||
        lowerCleanBody.contains('received inr') ||
        lowerCleanBody.contains('received') ||
        lowerCleanBody.contains('deposited') ||
        lowerCleanBody.contains('added to your') ||
        lowerCleanBody.contains('transferred to your a/c') ||
        lowerCleanBody.contains('transferred to your account');

    bool isCredit = false;
    bool isDebit = false;

    if (hasCreditKeyword) {
      isCredit = true;
      // If credit/refund keywords are present, do not allow payment words
      // (like "paid", "order", "unauthorized debit") to invert to expense.
      isDebit = false;
    } else if (lowerCleanBody.contains('sent rs.') ||
        lowerCleanBody.contains('sent rs ') ||
        lowerCleanBody.contains('sent inr')) {
      isDebit = true;
    } else {
      // Keyword-based detection
      isDebit =
          lowerCleanBody.contains('debit') ||
          lowerCleanBody.contains('debited') ||
          lowerCleanBody.contains('spent') ||
          lowerCleanBody.contains('charged') ||
          lowerCleanBody.contains('paid') ||
          lowerCleanBody.contains('transacted') ||
          lowerCleanBody.contains('withdrawn') ||
          lowerCleanBody.contains('payment of') ||
          lowerCleanBody.contains('transferred from');
    }

    if (!isCredit && !isDebit) return null;

    final isIncome = isCredit && !isDebit;

    // Amount extraction
    double? amount;
    String rawMerchant = 'Bank transaction';
    String? payee;

    final amountMatch =
        RegExp(
          r'(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]+)?)',
          caseSensitive: false,
        ).firstMatch(cleanBody) ??
        RegExp(
          r'([0-9,]+\.[0-9]+)\s*(?:INR|Rs\.?)',
          caseSensitive: false,
        ).firstMatch(cleanBody) ??
        RegExp(
          r'([0-9,]{2,})\s*(?:INR|Rs\.?)(?!\w)',
          caseSensitive: false,
        ).firstMatch(cleanBody);
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

    var merchantMatch = primaryRegex.firstMatch(cleanBody);

    // Fallback if primary preposition wasn't found
    merchantMatch ??= RegExp(
      r"(?:towards|to|from|at|paid\s+on|(?:on\s+(?![0-9])))\s*([a-zA-Z0-9\s\.'&,\-@]+?)(?:\s+on\s+\d|\s+at\s+\d|\s+(?:ref|txn|upi|not|refer|regards|credited)[\s:]|(?:\s+\.\s+)|(?:\.\s*$)|$)",
      caseSensitive: false,
    ).firstMatch(cleanBody);

    if (merchantMatch != null) {
      var extracted = merchantMatch.group(1)!.trim();
      // Remove VPA handle suffixes (e.g. @oksbi, @ybl, @okicici, @axl, @paytm)
      extracted = extracted
          .replaceAll(RegExp(r'@[a-zA-Z0-9\.\-_]+'), '')
          .trim();
      // Remove trailing URLs or fraud alert disclaimers
      extracted = extracted
          .replaceAll(RegExp(r'https?://\S+.*$', caseSensitive: false), '')
          .trim();
      extracted = extracted
          .replaceAll(RegExp(r'not you.*$', caseSensitive: false), '')
          .trim();
      if (extracted.isNotEmpty && extracted.length < 60) {
        rawMerchant = extracted;
        payee = extracted;
      }
    }

    // Clean up if it contains generic wallet app names
    if (rawMerchant.toLowerCase().contains('gpay') ||
        rawMerchant.toLowerCase().contains('google pay') ||
        rawMerchant.toLowerCase().contains('phonepe') ||
        rawMerchant.toLowerCase().contains('paytm')) {
      const walletTokens = {'gpay', 'google', 'pay', 'phonepe', 'paytm'};
      final parts = rawMerchant.split(RegExp(r'\s+'));
      rawMerchant = parts
          .where(
            (p) => !walletTokens.contains(
              p.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), ''),
            ),
          )
          .join(' ');
      if (rawMerchant.trim().isEmpty) rawMerchant = 'UPI transaction';
    }

    // Auto-detect category: user rules first, then built-in detection
    String categoryId = 'other';
    bool userRuleMatched = false;
    if (keywordToCategory != null && keywordToCategory.isNotEmpty) {
      final cleanMerchant = rawMerchant.toLowerCase();
      for (final entry in keywordToCategory.entries) {
        // A rule's keyword field may hold a whole comma-separated list
        // ("zomato, swiggy, kfc") — match against each individual keyword,
        // not the entire list as one string.
        final keywords = entry.key
            .split(',')
            .map((k) => k.trim().toLowerCase())
            .where((k) => k.isNotEmpty);
        for (final keyword in keywords) {
          if (cleanMerchant.contains(keyword)) {
            categoryId = entry.value;
            userRuleMatched = true;
            break;
          }
        }
        if (userRuleMatched) break;
      }
    }
    if (!userRuleMatched) {
      categoryId = _detectCategoryFromMerchant(rawMerchant);
    }

    // Income defaults to 'income' only when no user rule matched
    if (isIncome && !userRuleMatched) {
      categoryId = 'income';
    }

    // Parse date & time from SMS body, falling back to override or now
    final parsedDate = dateOverride ?? _extractDate(body) ?? DateTime.now();

    return ParsedSmsTxn(
      amount: amount,
      note: '', // Always empty for user notes!
      categoryId: categoryId,
      date: parsedDate,
      isIncome: isIncome,
      payee: payee ?? rawMerchant,
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

    final timeMatch = RegExp(
      r'(?<!\d)(\d{1,2}):(\d{2})(?::(\d{2}))?(?::\d{2})?\s*(am|pm)?',
      caseSensitive: false,
    ).firstMatch(body);
    if (timeMatch != null) {
      final h = int.parse(timeMatch.group(1)!);
      final m = int.parse(timeMatch.group(2)!);
      final s = int.tryParse(timeMatch.group(3) ?? '') ?? 0;
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59 && s >= 0 && s <= 59) {
        hour = h;
        minute = m;
        second = s;
        final ampm = timeMatch.group(4)?.toLowerCase();
        if (ampm == 'pm' && hour < 12) {
          hour += 12;
        } else if (ampm == 'am' && hour == 12) {
          hour = 0;
        }
      }
    }

    // YYYY-MM-DD or YYYY/MM/DD (must run before DMY, which would
    // otherwise match "26-08-22" inside "2026-08-22")
    final ymd = RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})').firstMatch(body);
    if (ymd != null) {
      final year = int.parse(ymd.group(1)!);
      final month = int.parse(ymd.group(2)!);
      final day = int.parse(ymd.group(3)!);
      if (month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= DateTime(year, month + 1, 0).day) {
        return DateTime(year, month, day, hour, minute, second);
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
      if (month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= DateTime(year, month + 1, 0).day) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

    // DD Mon YYYY or DD Mon YY (e.g. "22 Jul 2026", "22 Jul 26")
    final dMonY = RegExp(
      r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{2,4})',
      caseSensitive: false,
    ).firstMatch(body);
    if (dMonY != null) {
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final month = months[dMonY.group(2)!.toLowerCase().substring(0, 3)];
      final day = int.parse(dMonY.group(1)!);
      var year = int.parse(dMonY.group(3)!);
      if (year < 100) year += 2000;
      if (month != null &&
          day >= 1 &&
          day <= DateTime(year, month + 1, 0).day) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

    return null;
  }

  static String _detectCategoryFromMerchant(String note) {
    final cleanNote = note.toLowerCase();

    if (cleanNote.contains('starbucks') ||
        cleanNote.contains('swiggy') ||
        cleanNote.contains('zomato') ||
        cleanNote.contains('restaurant') ||
        cleanNote.contains('cafe') ||
        cleanNote.contains('food') ||
        cleanNote.contains('mcdonalds') ||
        cleanNote.contains('kfc') ||
        cleanNote.contains('diner') ||
        cleanNote.contains('baker') ||
        cleanNote.contains('pizza') ||
        cleanNote.contains('burger') ||
        cleanNote.contains('domino') ||
        cleanNote.contains('subway') ||
        cleanNote.contains('dhaba')) {
      return 'food';
    }

    if (cleanNote.contains('uber') ||
        cleanNote.contains('ola') ||
        cleanNote.contains('metro') ||
        cleanNote.contains('petrol') ||
        cleanNote.contains('fuel') ||
        cleanNote.contains('shell') ||
        cleanNote.contains('railway') ||
        cleanNote.contains('taxi') ||
        cleanNote.contains('irctc') ||
        cleanNote.contains('bus')) {
      return 'transport';
    }

    if (cleanNote.contains('amazon') ||
        cleanNote.contains('flipkart') ||
        cleanNote.contains('myntra') ||
        cleanNote.contains('shopping') ||
        cleanNote.contains('zara') ||
        cleanNote.contains('groceries') ||
        cleanNote.contains('supermarket') ||
        cleanNote.contains('store') ||
        cleanNote.contains('mart') ||
        cleanNote.contains('ajio') ||
        cleanNote.contains('nykaa') ||
        cleanNote.contains('h&m')) {
      return 'shopping';
    }

    if (cleanNote.contains('bill') ||
        cleanNote.contains('electricity') ||
        cleanNote.contains('broadband') ||
        cleanNote.contains('recharge') ||
        cleanNote.contains('water') ||
        cleanNote.contains('gas') ||
        cleanNote.contains('insurance') ||
        cleanNote.contains('bsnl') ||
        cleanNote.contains('jio') ||
        cleanNote.contains('airtel') ||
        cleanNote.contains('netflix') ||
        cleanNote.contains('spotify')) {
      return 'bills';
    }

    if (cleanNote.contains('pvr') ||
        cleanNote.contains('bookmyshow') ||
        cleanNote.contains('steam') ||
        cleanNote.contains('movie') ||
        cleanNote.contains('cinema')) {
      return 'entertainment';
    }

    return 'other';
  }
}
