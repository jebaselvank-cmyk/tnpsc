import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class StreakBadge extends StatelessWidget {
  final int streak;
  const StreakBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak < 7) return const SizedBox.shrink();

    String icon = '🎖️';

    if (streak >= 30) {
      icon = '👑';
    } else if (streak >= 14) {
      icon = '🛡️';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      // decoration: BoxDecoration(
      //   color: color.withValues(alpha: 0.1),
      //   borderRadius: BorderRadius.circular(12),
      //   border: Border.all(color: color.withValues(alpha: 0.3)),
      // ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: AppTheme.getStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
