/// A keyword-to-category mapping rule for auto-categorization.
class CategorizationRule {
  final String keyword;       // comma-separated keywords
  String categoryId;           // the category to assign

  CategorizationRule({required this.keyword, required this.categoryId});

  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'categoryId': categoryId,
  };

  factory CategorizationRule.fromJson(Map<String, dynamic> json) =>
      CategorizationRule(
        keyword: json['keyword'] as String,
        categoryId: json['categoryId'] as String,
      );

  /// Build a regex from the comma-separated keywords for matching.
  /// Handles both `', '` and `','` formats.
  RegExp toRegExp() =>
      RegExp(keyword.split(',').map((s) => s.trim()).join('|'), caseSensitive: false);

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
      keyword: 'bill, electricity, water, internet, recharge, phone, jio, airtel',
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
