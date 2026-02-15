import 'package:flutter/material.dart';
import 'package:my_day/core/theme/app_theme.dart';

class WaveformVisualizer extends StatelessWidget {
  const WaveformVisualizer({super.key, required this.levels});
  final List<double> levels;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(
        levels.isEmpty ? 24 : levels.length,
        (int index) {
          final double level = levels.isEmpty ? 0.1 : levels[index].clamp(0, 1);
          final double height = 6 + (level * 36);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Align(
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  key: Key('waveform-bar-$index'),
                  height: height,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
