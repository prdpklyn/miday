import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_day/core/theme/app_theme.dart';
import 'package:my_day/presentation/providers/insights_provider.dart';
import 'package:my_day/presentation/widgets/floating_ai_button.dart';
import 'dart:math' as math;

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text('Insights'),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Content
                Expanded(
                  child: insightsAsync.when(
                    data: (insights) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Productivity Score Circle
                            Center(
                              child: _ProductivityCircle(score: insights.productivityScore),
                            ),

                            const SizedBox(height: 32),

                            // AI Insight Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8B7CF6), Color(0xFF4EA8DE)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      insights.aiInsight,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Stats
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    title: 'Completed',
                                    value: insights.tasksCompletedThisWeek.toString(),
                                    icon: Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _StatCard(
                                    title: 'Total Tasks',
                                    value: insights.totalTasks.toString(),
                                    icon: Icons.list_alt,
                                    color: AppTheme.accentBlue,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 100),
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),
          const FloatingAIButton(),
        ],
      ),
    );
  }
}

class _ProductivityCircle extends StatelessWidget {
  final int score;

  const _ProductivityCircle({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: _CirclePainter(score: score),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score%',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              const Text(
                'Productivity',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  final int score;

  _CirclePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8B7CF6), Color(0xFF4EA8DE)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * (score / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) => oldDelegate.score != score;
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
