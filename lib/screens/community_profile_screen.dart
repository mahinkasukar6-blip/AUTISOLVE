import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CommunityProfileScreen extends StatelessWidget {
  final String name;
  final String role;
  final String bio;

  final String? distance;
  final String? rating;

  final bool isSpecialist;

  final String practiceYears;
  final String clinicName;
  final String consultationFee;
  final String location;
  final String timings;
  final String procedures;
  final String education;
  final String experience;

  const CommunityProfileScreen({
    super.key,
    required this.name,
    required this.role,
    required this.bio,
    this.distance,
    this.rating,
    required this.isSpecialist,
    this.practiceYears = '8 years',
    this.clinicName = 'Autisolve Child Development Centre',
    this.consultationFee = '₹1,500',
    this.location = 'Pune, Maharashtra',
    this.timings = 'Mon - Sat • 10:00 AM - 6:00 PM',
    this.procedures =
        'Developmental assessment, communication guidance, parent consultation',
    this.education = 'MBBS, MD Pediatrics',
    this.experience = 'Experienced in supporting children and families.',
  });

  @override
  Widget build(BuildContext context) {
    if (isSpecialist) {
      return _DoctorProfile(
        name: name,
        role: role,
        bio: bio,
        distance: distance ?? '1.8 km',
        rating: rating ?? '4.9',
        practiceYears: practiceYears,
        clinicName: clinicName,
        consultationFee: consultationFee,
        location: location,
        timings: timings,
        procedures: procedures,
        education: education,
        experience: experience,
      );
    }

    return _ParentProfile(name: name, role: role, bio: bio);
  }
}

// ============================================================
// PARENT PROFILE
// ============================================================

class _ParentProfile extends StatelessWidget {
  final String name;
  final String role;
  final String bio;

  const _ParentProfile({
    required this.name,
    required this.role,
    required this.bio,
  });

  @override
  Widget build(BuildContext context) {
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
          'Your profile',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          const SizedBox(height: 5),

          // PARENT ACCOUNT
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: AppColors.goldSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'P',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.goldDark,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Autisolve Companion Active',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // CHILD CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.sageLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🐼', style: TextStyle(fontSize: 28)),
                  ),
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Caring for Aarav (Age 5)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.sageDark,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Communication  •  Sensory needs',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _parentAction(
            context,
            title: 'Edit profile',
            icon: Icons.edit_outlined,
            onTap: () {
              _message(context, 'Edit profile will open here.');
            },
          ),

          _parentAction(
            context,
            title: 'Notifications',
            icon: Icons.notifications_none_rounded,
            onTap: () {
              _message(context, 'Notification settings will open here.');
            },
          ),

          _parentAction(
            context,
            title: 'Privacy & data',
            icon: Icons.lock_outline_rounded,
            onTap: () {
              _message(context, 'Privacy settings will open here.');
            },
          ),

          const SizedBox(height: 5),

          _parentAction(
            context,
            title: 'Log out',
            icon: Icons.logout_rounded,
            danger: true,
            onTap: () {
              _logoutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _parentAction(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 17),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: danger ? AppColors.coral : AppColors.inkSoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: danger ? AppColors.coral : AppColors.ink,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _logoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
              ),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// DOCTOR / SPECIALIST PROFILE
// ============================================================

class _DoctorProfile extends StatelessWidget {
  final String name;
  final String role;
  final String bio;
  final String distance;
  final String rating;
  final String practiceYears;
  final String clinicName;
  final String consultationFee;
  final String location;
  final String timings;
  final String procedures;
  final String education;
  final String experience;

  const _DoctorProfile({
    required this.name,
    required this.role,
    required this.bio,
    required this.distance,
    required this.rating,
    required this.practiceYears,
    required this.clinicName,
    required this.consultationFee,
    required this.location,
    required this.timings,
    required this.procedures,
    required this.education,
    required this.experience,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.sage,
        foregroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),

        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile sharing will be added here.'),
                ),
              );
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),

      body: ListView(
        children: [
          _doctorHeader(),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: Column(
              children: [
                _clinicCard(),

                const SizedBox(height: 14),

                _informationCard(
                  icon: Icons.medical_services_outlined,
                  title: 'Procedures & services',
                  child: Text(
                    procedures,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                _informationCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Introduction',
                  child: Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                _informationCard(
                  icon: Icons.school_outlined,
                  title: 'Education',
                  child: Text(
                    education,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                _informationCard(
                  icon: Icons.work_outline_rounded,
                  title: 'Experience',
                  child: Text(
                    experience,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Consultation booking will be added here.',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Book consultation',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctorHeader() {
    return Container(
      color: AppColors.sage,
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: Column(
        children: [
          Container(
            width: 94,
            height: 94,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 54,
              color: AppColors.sageDark,
            ),
          ),

          const SizedBox(height: 13),

          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            role,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),

          const SizedBox(height: 13),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _headerStat(Icons.star_rounded, rating),
              const SizedBox(width: 24),
              _headerStat(Icons.work_outline, practiceYears),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 17, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  'Verified specialist',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _clinicCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_hospital_outlined,
                color: AppColors.sageDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  clinicName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 24, color: AppColors.border),

          _clinicRow(Icons.location_on_outlined, location),

          const SizedBox(height: 11),

          _clinicRow(Icons.access_time_outlined, timings),

          const SizedBox(height: 11),

          _clinicRow(
            Icons.currency_rupee,
            'Consultation fee: $consultationFee',
          ),

          const SizedBox(height: 11),

          _clinicRow(Icons.near_me_outlined, '$distance from you'),
        ],
      ),
    );
  }

  Widget _clinicRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.inkFaint),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }

  Widget _informationCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
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
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          child,
        ],
      ),
    );
  }
}
