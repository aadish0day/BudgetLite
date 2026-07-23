class ParsedSmsTxn {
  final double amount;
  final String note;
  final String categoryId;
  final DateTime date;
  final String id;
  final DateTime detectedAt;

  ParsedSmsTxn({
    required this.amount,
    required this.note,
    required this.categoryId,
    required this.date,
    String? id,
    DateTime? detectedAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        detectedAt = detectedAt ?? DateTime.now();

  /// Serialize to a JSON map for storage in AppSettings
  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'note': note,
    'categoryId': categoryId,
    'date': date.toIso8601String(),
    'detectedAt': detectedAt.toIso8601String(),
  };

  /// Deserialize from a JSON map
  factory ParsedSmsTxn.fromJson(Map<String, dynamic> json) => ParsedSmsTxn(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    note: json['note'] as String,
    categoryId: json['categoryId'] as String,
    date: DateTime.parse(json['date'] as String),
    detectedAt: DateTime.parse(json['detectedAt'] as String),
  );
}

class SmsParser {
  static ParsedSmsTxn? parseMessage(String body) {
    final lowerBody = body.toLowerCase();
    
    // Quick heuristic filter to see if this is an SMS about spending/debiting
    bool isTransaction = lowerBody.contains('debit') ||
        lowerBody.contains('spent') ||
        lowerBody.contains('charged') ||
        lowerBody.contains('txn') ||
        lowerBody.contains('transacted') ||
        lowerBody.contains('spends') ||
        lowerBody.contains('paid');

    if (!isTransaction) return null;

    // Try to find amount: Rs. 500, Rs 500, INR 500, ₹ 500, etc.
    final amountReg = RegExp(
      r'(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    );
    final amountMatch = amountReg.firstMatch(body);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    // Try to find merchant name: e.g., "at Starbucks", "to Amazon"
    final merchantReg = RegExp(
      r'(?:at|to|in|on|info)\s+([a-zA-Z0-9\.\s\-\*&]+?)(?:\s+on|\s+at|\s+via|\s+using|\s+date|\s+ref|\.|$)',
      caseSensitive: false,
    );
    final merchantMatch = merchantReg.firstMatch(body);
    String note = 'Bank transaction';
    String categoryId = 'other';

    if (merchantMatch != null) {
      final rawNote = merchantMatch.group(1)!.trim();
      // Clean up note (remove trailing garbage like transaction IDs or extra spaces)
      if (rawNote.isNotEmpty && rawNote.length < 35) {
        note = rawNote;
      }
      
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
          cleanNote.contains('baker')) {
        categoryId = 'food';
      } else if (cleanNote.contains('uber') ||
          cleanNote.contains('ola') ||
          cleanNote.contains('metro') ||
          cleanNote.contains('petrol') ||
          cleanNote.contains('fuel') ||
          cleanNote.contains('shell') ||
          cleanNote.contains('railway') ||
          cleanNote.contains('taxi') ||
          cleanNote.contains('irctc')) {
        categoryId = 'transport';
      } else if (cleanNote.contains('rent') ||
          cleanNote.contains('landlord') ||
          cleanNote.contains('pg') ||
          cleanNote.contains('housing')) {
        categoryId = 'rent';
      } else if (cleanNote.contains('amazon') ||
          cleanNote.contains('flipkart') ||
          cleanNote.contains('myntra') ||
          cleanNote.contains('shopping') ||
          cleanNote.contains('zara') ||
          cleanNote.contains('groceries') ||
          cleanNote.contains('supermarket') ||
          cleanNote.contains('store') ||
          cleanNote.contains('mart')) {
        categoryId = 'shopping';
      } else if (cleanNote.contains('bill') ||
          cleanNote.contains('electricity') ||
          cleanNote.contains('broadband') ||
          cleanNote.contains('recharge') ||
          cleanNote.contains('water') ||
          cleanNote.contains('gas') ||
          cleanNote.contains('insurance') ||
          cleanNote.contains('bsnl') ||
          cleanNote.contains('jio') ||
          cleanNote.contains('airtel')) {
        categoryId = 'bills';
      }
    }

    return ParsedSmsTxn(
      amount: amount,
      note: note,
      categoryId: categoryId,
      date: DateTime.now(),
    );
  }
}
