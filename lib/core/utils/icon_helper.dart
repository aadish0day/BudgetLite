import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

IconData getCategoryIcon(String iconName) {
  final cleanName = iconName.trim().toLowerCase();

  // Direct match map
  final iconMap = {
    'restaurant': LucideIcons.utensils,
    'food': LucideIcons.utensils,
    'directions_car': LucideIcons.carFront,
    'transport': LucideIcons.carFront,
    'car': LucideIcons.carFront,
    'home': LucideIcons.house,
    'shopping_bag': LucideIcons.shoppingBag,
    'shopping': LucideIcons.shoppingBag,
    'receipt': LucideIcons.receiptText,
    'bills': LucideIcons.receiptText,
    'local_hospital': LucideIcons.hospital,
    'medical': LucideIcons.hospital,
    'health': LucideIcons.hospital,
    'school': LucideIcons.graduationCap,
    'education': LucideIcons.graduationCap,
    'flight': LucideIcons.plane,
    'travel': LucideIcons.plane,
    'entertainment': LucideIcons.film,
    'movie': LucideIcons.film,
    'more_horiz': LucideIcons.ellipsis,
    'other': LucideIcons.ellipsis,
    'fitness_center': LucideIcons.dumbbell,
    'fitness': LucideIcons.dumbbell,
    'gym': LucideIcons.dumbbell,
    'card_giftcard': LucideIcons.gift,
    'gift': LucideIcons.gift,
    'sports_esports': LucideIcons.gamepad2,
    'game': LucideIcons.gamepad2,
    'gaming': LucideIcons.gamepad2,
    'gamepad_2': LucideIcons.gamepad2,
    'gamepad2': LucideIcons.gamepad2,
    'work_outline': LucideIcons.briefcaseBusiness,
    'work': LucideIcons.briefcaseBusiness,
    'income': LucideIcons.landmark,
    'salary': LucideIcons.landmark,
    'account_balance': LucideIcons.landmark,
    'savings': LucideIcons.piggyBank,
    'wallet': LucideIcons.wallet,
    'flag': LucideIcons.flag,
    'star': LucideIcons.star,
    'heart': LucideIcons.heart,
    'favorite': LucideIcons.heart,
  };

  return iconMap[cleanName] ?? LucideIcons.circleHelp;
}
