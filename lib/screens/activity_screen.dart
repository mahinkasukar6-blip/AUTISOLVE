import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'speaking_practice_screen.dart';
import '../theme/app_colors.dart';

class ActivityItem {
  final String title;
  final String description;
  final String streak;
  final IconData icon;
  final Color iconBackground;
  bool completed;

  ActivityItem({
    required this.title,
    required this.description,
    required this.streak,
    required this.icon,
    required this.iconBackground,
    this.completed = false,
  });
}

class ActivitiesScreen extends StatefulWidget {
  final String childName;

  const ActivitiesScreen({super.key, required this.childName});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final List<ActivityItem> _activities = [
    ActivityItem(
      title: 'Speaking Practice',
      description: 'Naming objects & sounds',
      streak: '4d streak',
      icon: Icons.chat_bubble_outline_rounded,
      iconBackground: AppColors.sageLight,
    ),
    ActivityItem(
      title: 'Drawing Time',
      description: 'Free-form or guided',
      streak: '7d streak',
      icon: Icons.image_outlined,
      iconBackground: AppColors.sageLight,
    ),
    ActivityItem(
      title: 'Puzzle Play',
      description: 'Shape & pattern matching',
      streak: '2d streak',
      icon: Icons.assignment_outlined,
      iconBackground: AppColors.goldSoft,
    ),
    ActivityItem(
      title: 'Eating Independently',
      description: 'Self-feeding at meals',
      streak: '9d streak',
      icon: Icons.star_outline_rounded,
      iconBackground: AppColors.sageLight,
    ),
    ActivityItem(
      title: 'Eye Contact Games',
      description: 'Peekaboo, mirroring',
      streak: '1d streak',
      icon: Icons.auto_awesome,
      iconBackground: AppColors.goldSoft,
    ),
  ];

  final TextEditingController _customController = TextEditingController();

  bool _isLoading = true;
  bool _isAdding = false;
  final Set<String> _savingTitles = {};

  CollectionReference<Map<String, dynamic>> get _activityCollection =>
      FirebaseFirestore.instance.collection('activities');

  CollectionReference<Map<String, dynamic>> get _completionCollection =>
      FirebaseFirestore.instance.collection('activityCompletions');

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _completionId(String uid, String title) {
    // Encode the title to avoid collisions caused by spaces or slashes.
    final encodedTitle = Uri.encodeComponent(title);
    return '${uid}_${Uri.encodeComponent(widget.childName)}_'
        '${encodedTitle}_${_dateKey()}';
  }

  IconData _iconForActivity(String title) {
    switch (title) {
      case 'Speaking Practice':
        return Icons.chat_bubble_outline_rounded;
      case 'Drawing Time':
        return Icons.image_outlined;
      case 'Puzzle Play':
        return Icons.assignment_outlined;
      case 'Eating Independently':
        return Icons.star_outline_rounded;
      case 'Eye Contact Games':
        return Icons.auto_awesome;
      case 'Brush Teeth':
        return Icons.cleaning_services_outlined;
      default:
        return Icons.add_task_rounded;
    }
  }

  Color _backgroundForActivity(String title) {
    if (title == 'Puzzle Play' || title == 'Eye Contact Games') {
      return AppColors.goldSoft;
    }
    return AppColors.sageLight;
  }

  Future<void> _loadActivities() async {
    if (_currentUser == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await _activityCollection
          .where('isActive', isEqualTo: true)
          .get();

      final firebaseActivities = <String, ActivityItem>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final title = data['title'] as String?;

        if (title == null || title.trim().isEmpty) continue;

        firebaseActivities[title] = ActivityItem(
          title: title,
          description: data['description'] as String? ?? '',
          streak: 'New',
          icon: _iconForActivity(title),
          iconBackground: _backgroundForActivity(title),
        );
      }

      final mergedActivities = <ActivityItem>[];
      final existingTitles = <String>{};

      for (final existing in _activities) {
        final fromFirebase = firebaseActivities[existing.title];

        if (fromFirebase != null) {
          mergedActivities.add(
            ActivityItem(
              title: fromFirebase.title,
              description: fromFirebase.description.isNotEmpty
                  ? fromFirebase.description
                  : existing.description,
              streak: existing.streak,
              icon: fromFirebase.icon,
              iconBackground: fromFirebase.iconBackground,
            ),
          );
        } else {
          mergedActivities.add(
            ActivityItem(
              title: existing.title,
              description: existing.description,
              streak: existing.streak,
              icon: existing.icon,
              iconBackground: existing.iconBackground,
            ),
          );
        }

        existingTitles.add(existing.title);
      }

      for (final entry in firebaseActivities.entries) {
        if (!existingTitles.contains(entry.key)) {
          mergedActivities.add(entry.value);
        }
      }

      const activityOrder = [
        'Speaking Practice',
        'Brush Teeth',
        'Drawing Time',
        'Puzzle Play',
        'Eating Independently',
        'Eye Contact Games',
      ];

      mergedActivities.sort((a, b) {
        final aIndex = activityOrder.indexOf(a.title);
        final bIndex = activityOrder.indexOf(b.title);
        final aOrder = aIndex == -1 ? activityOrder.length : aIndex;
        final bOrder = bIndex == -1 ? activityOrder.length : bIndex;
        return aOrder.compareTo(bOrder);
      });

      if (!mounted) return;

      setState(() {
        _activities
          ..clear()
          ..addAll(mergedActivities);
      });

      await _loadTodayCompletions();
    } catch (error) {
      debugPrint('Error loading activities: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load activities from Firebase. '
            'Check your sign-in and Firestore rules.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTodayCompletions() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      // Filter by parentUid so Firestore rules can authorize this query.
      final snapshot = await _completionCollection
          .where('parentUid', isEqualTo: user.uid)
          .get();

      final today = _startOfToday();
      final completedTitles = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (data['childName'] != widget.childName) continue;

        final timestamp = data['completedAt'];
        if (timestamp is! Timestamp) continue;

        final completedDate = timestamp.toDate();
        final sameDay =
            completedDate.year == today.year &&
            completedDate.month == today.month &&
            completedDate.day == today.day;

        if (sameDay && data['activityTitle'] is String) {
          completedTitles.add(data['activityTitle'] as String);
        }
      }

      if (!mounted) return;

      setState(() {
        for (final activity in _activities) {
          activity.completed = completedTitles.contains(activity.title);
        }
      });
    } catch (error) {
      debugPrint('Error loading completion records: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _toggle(int index) async {
    final user = _currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save activity progress.'),
        ),
      );
      return;
    }

    final activity = _activities[index];

    if (_savingTitles.contains(activity.title)) return;

    final wasCompleted = activity.completed;
    final completionRef = _completionCollection.doc(
      _completionId(user.uid, activity.title),
    );

    setState(() {
      _savingTitles.add(activity.title);
    });

    try {
      if (wasCompleted) {
        await completionRef.delete();
      } else {
        await completionRef.set({
          'parentUid': user.uid,
          'childName': widget.childName,
          'activityTitle': activity.title,
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      setState(() {
        activity.completed = !wasCompleted;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasCompleted
                ? 'Activity marked incomplete.'
                : 'Activity completion saved!',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Error saving completion: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save progress. Check Firebase permissions.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingTitles.remove(activity.title);
        });
      }
    }
  }

  void _openActivity(int index) {
    final activity = _activities[index];

    if (activity.title == 'Speaking Practice') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SpeakingPracticeScreen(childName: widget.childName),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(activity.icon, color: AppColors.sageDark, size: 42),
                const SizedBox(height: 14),
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  activity.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _toggle(index);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      activity.completed ? 'Mark incomplete' : 'Mark complete',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addActivity() async {
    final user = _currentUser;
    final title = _customController.text.trim();

    if (title.isEmpty || _isAdding) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add an activity.')),
      );
      return;
    }

    final alreadyExists = _activities.any(
      (activity) => activity.title.toLowerCase() == title.toLowerCase(),
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This activity already exists.')),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      await _activityCollection.add({
        'title': title,
        'category': 'Personal',
        'description': 'Personal activity',
        'duration': '5 minutes',
        'instructions': <String>[],
        'isActive': true,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _customController.clear();
      await _loadActivities();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity saved successfully!')),
      );
    } catch (error) {
      debugPrint('Error saving activity: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save activity. Check Firebase permissions.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  int get _completed =>
      _activities.where((activity) => activity.completed).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      children: [
        const Text(
          "Today's activities",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap to mark what you got through today.',
          style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 24),
        ...List.generate(
          _activities.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _buildCard(index),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customController,
                onSubmitted: (_) => _addActivity(),
                decoration: InputDecoration(
                  hintText: 'Add your own activity...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 54,
              height: 54,
              child: ElevatedButton(
                onPressed: _isAdding ? null : _addActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '$_completed of ${_activities.length} completed',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.inkFaint),
        ),
      ],
    );
  }

  Widget _buildCard(int index) {
    final activity = _activities[index];
    final isSaving = _savingTitles.contains(activity.title);

    return InkWell(
      onTap: () => _openActivity(index),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: activity.iconBackground,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                activity.icon,
                color: activity.iconBackground == AppColors.goldSoft
                    ? AppColors.goldDark
                    : AppColors.sageDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.streak,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: isSaving ? null : () => _toggle(index),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: activity.completed ? AppColors.sage : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: activity.completed
                        ? AppColors.sage
                        : AppColors.border,
                  ),
                ),
                child: isSaving
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : activity.completed
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
