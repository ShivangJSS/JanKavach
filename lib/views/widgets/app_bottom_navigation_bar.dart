import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';

/// Centralized navigation coordinator for post-login dashboard tabs.
class AppNavigationController {
  static final ValueNotifier<int> activeTab = ValueNotifier<int>(0);

  /// Navigates to the specified tab.
  /// If on a pushed sub-screen, pops until the root route (DashboardScreen)
  /// and updates the active tab.
  static void navigateToTab(BuildContext context, int targetTab, {int? currentTab}) {
    activeTab.value = targetTab;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

/// Standardized, persistent bottom navigation bar used across all post-login screens.
class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTabSelected;

  static const Color green = Color(0xFF21834A);
  static const Color muted = Color(0xFF6B7280);

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.tr('dashboard.nav_home'),
      context.tr('dashboard.nav_beneficiaries'),
      context.tr('dashboard.nav_schemes'),
      context.tr('dashboard.nav_support'),
    ];

    const icons = [
      Icons.home_rounded,
      Icons.people_outline_rounded,
      Icons.account_balance_outlined,
      Icons.support_agent_rounded,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = currentIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (onTabSelected != null) {
                      onTabSelected!(index);
                    } else {
                      AppNavigationController.navigateToTab(
                        context,
                        index,
                        currentTab: currentIndex,
                      );
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? green : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          icons[index],
                          size: 21,
                          color: selected ? Colors.white : muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[index],
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? green : muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
