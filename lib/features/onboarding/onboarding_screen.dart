import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final _pages = [
    _OnboardingPageData(
      icon: LucideIcons.wallet,
      title: 'Welcome to BudgetLite',
      subtitle: 'Take control of your finances with smart, effortless budgeting.',
      color: AppColors.primary,
    ),
    _OnboardingPageData(
      icon: LucideIcons.chartPie,
      title: 'Track Every Rupee',
      subtitle: 'Log expenses, set budgets, and see where your money goes at a glance.',
      color: AppColors.secondary,
    ),
    _OnboardingPageData(
      icon: LucideIcons.trendingUp,
      title: 'Save for What Matters',
      subtitle: 'Set savings goals, track progress, and build better money habits.',
      color: AppColors.accent,
    ),
    _OnboardingPageData(
      icon: LucideIcons.shield,
      title: 'Offline & Private',
      subtitle: 'Your data stays on your device — no cloud, no tracking, full privacy.',
      color: AppColors.primaryLight,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: page.color.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            page.icon,
                            size: 56,
                            color: page.color,
                          ),
                        ).animate().fadeIn(
                          duration: 600.ms,
                          delay: 100.ms,
                        ).scaleXY(begin: 0.8, end: 1),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          style: AppTheme.displayStyle(
                            size: 26,
                            weight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(
                          duration: 500.ms,
                          delay: 250.ms,
                        ).slideY(begin: 0.1),
                        const SizedBox(height: 16),
                        Text(
                          page.subtitle,
                          style: AppTheme.bodyStyle(
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(
                          duration: 500.ms,
                          delay: 400.ms,
                        ).slideY(begin: 0.05),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: 300.ms,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPage == i
                          ? _pages[i].color
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FilledButton(
                onPressed: () {
                  if (_currentPage == _pages.length - 1) {
                    widget.onComplete();
                  } else {
                    _controller.nextPage(
                      duration: 300.ms,
                      curve: Curves.easeInOut,
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: _pages[_currentPage].color,
                ),
                child: Text(
                  _currentPage == _pages.length - 1
                      ? 'Get Started'
                      : 'Continue',
                  style: AppTheme.bodyStyle(
                    size: 16,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (_currentPage < _pages.length - 1)
              TextButton(
                onPressed: widget.onComplete,
                child: Text(
                  'Skip',
                  style: AppTheme.bodyStyle(
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              const SizedBox(height: 48),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
