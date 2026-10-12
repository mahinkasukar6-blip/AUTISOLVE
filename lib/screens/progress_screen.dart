import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'progress_report_screen.dart';

class ProgressScreen extends StatelessWidget {
  final String childName;

  const ProgressScreen({super.key, required this.childName});

  DateTime _startOfWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  void _openScreening(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.sageDark,
                  size: 40,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Quick screening checklist',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This prototype checklist will contain '
                  '10 simple questions for parents.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Screening questionnaire will open here.',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text('Start checklist'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openReport(
    BuildContext context,
    int totalActivities,
    String mostConsistentDay,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProgressReportScreen(
          childName: childName,
          totalActivities: totalActivities,
          mostConsistentDay: mostConsistentDay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Please sign in to view your child's progress.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft),
          ),
        ),
      );
    }

    final weekStart = _startOfWeek();
    final weekEnd = weekStart.add(const Duration(days: 7));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('activityCompletions')
          .where('parentUid', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 42,
                    color: AppColors.sageDark,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load progress from Firebase.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data?.docs ?? [];
        final dailyActivities = List<int>.filled(7, 0);

        // Calculate counts from the real Firebase records.
        // The query uses parentUid; date filtering is done here
        // to avoid requiring a compound date index.
        for (final doc in records) {
          final data = doc.data();
          final timestamp = data['completedAt'];

          if (timestamp is! Timestamp) continue;

          final completedAt = timestamp.toDate();

          if (completedAt.isBefore(weekStart) ||
              !completedAt.isBefore(weekEnd)) {
            continue;
          }

          // If this record has a childName, match the selected child.
          // Case-insensitive comparison avoids capitalization mismatches.
          final recordedChild = data['childName'];
          if (recordedChild is String &&
              recordedChild.trim().isNotEmpty &&
              recordedChild.trim().toLowerCase() !=
                  childName.trim().toLowerCase()) {
            continue;
          }

          final dayIndex = completedAt.weekday - 1;

          if (dayIndex >= 0 && dayIndex < 7) {
            dailyActivities[dayIndex]++;
          }
        }

        final totalActivities = dailyActivities.fold<int>(
          0,
          (total, count) => total + count,
        );

        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

        final highestCount = dailyActivities.reduce((a, b) => a > b ? a : b);

        final mostConsistentDay = highestCount == 0
            ? '—'
            : days[dailyActivities.indexOf(highestCount)];

        final maxBarValue = highestCount == 0 ? 1 : highestCount;

        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
          children: [
            const Text(
              'Progress tracker',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "$childName's activity over the last 7 days.",
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 22),

            // Screening checklist card
            InkWell(
              onTap: () => _openScreening(context),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: AppColors.sageDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Not sure where to start?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Take a quick 10-question screening checklist',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.inkFaint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Weekly activity chart
            Container(
              height: 210,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final value = dailyActivities[index];
                        final isHighest =
                            highestCount > 0 && value == highestCount;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '$value',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 28,
                                  height: highestCount == 0
                                      ? 4
                                      : 130 * value / maxBarValue,
                                  decoration: BoxDecoration(
                                    color: isHighest
                                        ? AppColors.sage
                                        : AppColors.goldSoft,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: days.map((day) {
                      return Expanded(
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Weekly statistics
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.sageLight,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalActivities',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.sageDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Activities this week',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mostConsistentDay,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.goldDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Most consistent day',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weekly summary
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 20,
                        color: AppColors.sageDark,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Weekly summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    totalActivities == 0
                        ? 'No activity completions have been recorded '
                              'for $childName this week yet. Complete and '
                              'record activities to start tracking progress.'
                        : '$childName has $totalActivities recorded '
                              'activity completions this week. '
                              '${mostConsistentDay == '—' ? '' : '$mostConsistentDay has the highest number of recorded completions.'}',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openReport(
                        context,
                        totalActivities,
                        mostConsistentDay,
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Summarise report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
