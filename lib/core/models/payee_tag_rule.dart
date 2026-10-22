import 'package:uuid/uuid.dart';

/// Represents an automated tagging and categorization rule for a specific person or merchant.
class PayeeTagRule {
  PayeeTagRule({
    required this.payee,
    required this.tag,
    this.categoryId,
    this.note,
    String? id,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory PayeeTagRule.fromJson(Map<String, dynamic> json) => PayeeTagRule(
        id: json['id'] as String?,
        payee: json['payee'] as String,
        tag: json['tag'] as String,
        categoryId: json['categoryId'] as String?,
        note: json['note'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  final String id;

  /// The person or merchant name to match against (e.g. "Satyanarayan Communi").
  final String payee;

  /// The tag to apply (e.g. "cig" or "chai"). Stored without brackets.
  final String tag;

  /// Optional category to assign (e.g. "food" or "other").
  final String? categoryId;

  /// Optional default note.
  final String? note;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'payee': payee,
        'tag': tag,
        'categoryId': categoryId,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Checks if a candidate payee matches this rule (case-insensitive and whitespace-tolerant).
  bool matches(String? candidatePayee) {
    if (candidatePayee == null) return false;
    final normalizedCandidate = candidatePayee.trim().toLowerCase();
    final normalizedRule = payee.trim().toLowerCase();
    if (normalizedCandidate.isEmpty || normalizedRule.isEmpty) return false;

    // Exact match or substring containment
    return normalizedCandidate == normalizedRule ||
        normalizedCandidate.contains(normalizedRule) ||
        normalizedRule.contains(normalizedCandidate);
  }

  PayeeTagRule copyWith({
    String? payee,
    String? tag,
    String? categoryId,
    String? note,
  }) {
    return PayeeTagRule(
      id: id,
      payee: payee ?? this.payee,
      tag: tag ?? this.tag,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }
}
