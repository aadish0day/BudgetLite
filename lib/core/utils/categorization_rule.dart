/// A keyword-to-category mapping rule for auto-categorization.
class CategorizationRule {
  // the category to assign

  CategorizationRule({required this.keyword, required this.categoryId});

  factory CategorizationRule.fromJson(Map<String, dynamic> json) =>
      CategorizationRule(
        keyword: json['keyword'] as String,
        categoryId: json['categoryId'] as String,
      );
  final String keyword; // comma-separated keywords
  String categoryId;

  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'categoryId': categoryId,
  };

  /// Build a regex from the comma-separated keywords for matching.
  /// Handles both `', '` and `','` formats. Keywords are escaped so
  /// metacharacters can't crash the regex or widen matching, and empty
  /// segments are dropped (an empty alternation branch matches everything).
  RegExp toRegExp() {
    final parts = keyword
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(RegExp.escape)
        .toList();
    if (parts.isEmpty) {
      // No usable keywords — a regex that can never match.
      return RegExp('(?!x)x');
    }
    return RegExp(parts.join('|'), caseSensitive: false);
  }

  /// Static default rules shown on first use.
  static List<CategorizationRule> defaults() => [
    CategorizationRule(
      keyword: 'zomato, swiggy, restaurant, cafe, food, mcdonalds, kfc, pizza',
      categoryId: 'food',
    ),
    CategorizationRule(
      keyword: 'uber, ola, metro, petrol, fuel, taxi, bus, train, cab, lyft',
      categoryId: 'transport',
    ),
    CategorizationRule(
      keyword: 'rent, maintenance, society, housing, landlord',
      categoryId: 'rent',
    ),
    CategorizationRule(
      keyword: 'amazon, flipkart, myntra, zara, shopping, clothes, mall',
      categoryId: 'shopping',
    ),
    CategorizationRule(
      keyword:
          'bill, electricity, water, internet, recharge, phone, jio, airtel',
      categoryId: 'bills',
    ),
    CategorizationRule(
      keyword: 'salary, income, credit, refund, cashback, bonus, dividend',
      categoryId: 'income',
    ),
    CategorizationRule(
      keyword: 'netflix, prime, hotstar, spotify, movie, cinema, game, play',
      categoryId: 'other',
    ),
  ];
}
