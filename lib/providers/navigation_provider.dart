import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the current bottom navigation tab index.
/// Allows any widget to switch tabs by writing to this provider.
final currentTabProvider = StateProvider<int>((ref) => 0);
