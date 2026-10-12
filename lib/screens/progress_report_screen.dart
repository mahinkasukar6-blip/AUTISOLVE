import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProgressReportScreen extends StatelessWidget {
  final String childName;
  final int totalActivities;
  final String mostConsistentDay;

  const ProgressReportScreen({
    super.key,
    required this.childName,
    required this.totalActivities,
    required this.mostConsistentDay,
  });

  DateTime _startOfWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view the weekly report.')),
      );
    }

    final weekStart = _startOfWeek();
    final weekEnd = weekStart.add(const Duration(days: 7));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
        ),
        title: const Text(
          'Weekly report',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report sharing will be added here.'),
                ),
              );
            },
            icon: const Icon(Icons.share_outlined, color: AppColors.ink),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('activityCompletions')
            .where('parentUid', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load the weekly report.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data?.docs ?? [];
          final dailyCounts = List<int>.filled(7, 0);
          final completedTitles = <String>{};

          for (final doc in records) {
            final data = doc.data();

            if (data['childName'] is String &&
                (data['childName'] as String).trim().toLowerCase() !=
                    childName.trim().toLowerCase()) {
              continue;
            }

            final timestamp = data['completedAt'];
            if (timestamp is! Timestamp) continue;

            final completedAt = timestamp.toDate();

            if (completedAt.isBefore(weekStart) ||
                !completedAt.isBefore(weekEnd)) {
              continue;
            }

            final dayIndex = completedAt.weekday - 1;
            if (dayIndex >= 0 && dayIndex < 7) {
              dailyCounts[dayIndex]++;
            }

            final title = data['activityTitle'];
            if (title is String && title.isNotEmpty) {
              completedTitles.add(title);
            }
          }

          final actualTotal = dailyCounts.fold<int>(
            0,
            (total, count) => total + count,
          );

          const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

          final highestCount = dailyCounts.reduce((a, b) => a > b ? a : b);

          final bestDay = highestCount == 0
              ? '—'
              : weekdays[dailyCounts.indexOf(highestCount)];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.sageDark,
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "$childName's Weekly Progress",
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'A summary of recorded activity and participation.',
                      style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _reportCard(
                title: 'Activity overview',
                icon: Icons.bar_chart_rounded,
                child: Column(
                  children: [
                    _reportRow('Activities completed', '$actualTotal'),
                    _reportRow('Most consistent day', bestDay),
                    _reportRow(
                      'Different activities completed',
                      '${completedTitles.length}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _reportCard(
                title: 'Daily activity',
                icon: Icons.calendar_today_outlined,
                child: Column(
                  children: List.generate(7, (index) {
                    final count = dailyCounts[index];
                    final fraction = highestCount == 0
                        ? 0.0
                        : count / highestCount;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              weekdays[index],
                              style: const TextStyle(color: AppColors.inkSoft),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 12,
                                backgroundColor: AppColors.sageLight,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.sage,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),

              _reportCard(
                title: 'Communication',
                icon: Icons.chat_bubble_outline_rounded,
                child: Text(
                  completedTitles.contains('Speaking Practice')
                      ? 'Speaking Practice has recorded completions this week. '
                            'Continue offering short, familiar words and allow '
                            'time for your child to respond.'
                      : 'No Speaking Practice completion is recorded this '
                            'week yet. Consider short, familiar words and '
                            'allow your child time to respond.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _reportCard(
                title: 'Daily routines',
                icon: Icons.calendar_today_outlined,
                child: Text(
                  completedTitles.contains('Brush Teeth') ||
                          completedTitles.contains('Eating Independently')
                      ? 'Daily routine activities appear in this week’s '
                            'records. Continue supporting familiar routines '
                            'at a comfortable pace.'
                      : 'No daily routine activity is recorded this week. '
                            'Consider practising familiar routines when your '
                            'child is comfortable.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _reportCard(
                title: 'Sensory needs',
                icon: Icons.spa_outlined,
                child: const Text(
                  'Observe which activities your child enjoys and when '
                  'breaks may help. Activity completion records alone '
                  'cannot determine sensory needs.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _reportCard(
                title: 'Suggested next steps',
                icon: Icons.arrow_forward_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bullet('Continue short speaking practice sessions.'),
                    _bullet('Keep successful routines consistent.'),
                    _bullet('Record completed activities regularly.'),
                    _bullet('Use the chatbot for additional activity ideas.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report download will be added here.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Save report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _reportCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.sageDark),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: AppColors.sage),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
