import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'community_profile_screen.dart';
import 'create_post_screen.dart';

class CommunityPost {
  final String? id;
  final String author;
  final String role;
  final String timeAgo;
  final String title;
  final String body;
  int likes;

  CommunityPost({
    this.id,
    required this.author,
    required this.role,
    required this.timeAgo,
    required this.title,
    required this.body,
    required this.likes,
  });
}

class CommunitySpecialist {
  final String name;
  final String role;
  final String distance;
  final String rating;
  final String bio;

  const CommunitySpecialist({
    required this.name,
    required this.role,
    required this.distance,
    required this.rating,
    required this.bio,
  });
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<CommunitySpecialist> _specialists = [
    const CommunitySpecialist(
      name: 'Dr. Alia Mehta',
      role: 'Developmental Pediatrician',
      distance: '1.8 km',
      rating: '4.9',
      bio: 'Provides developmental guidance for children and families, including communication, routines, and early support.',
    ),
    const CommunitySpecialist(
      name: 'Dr. Rohan Iyer',
      role: 'Child Psychologist',
      distance: '3.2 km',
      rating: '4.8',
      bio: 'Supports children and parents with emotional regulation, social development, and everyday challenges.',
    ),
  ];

  List<CommunityPost> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  List<CommunityPost> _samplePosts() {
    return [
      CommunityPost(
        author: 'Dr. Rohan Iyer',
        role: 'Child Psychologist',
        timeAgo: '1w ago',
        title: 'When to worry less about eye contact',
        body: 'Eye contact is one signal among many. Engagement can look like proximity, shared attention, or simply staying in the room with you.',
        likes: 201,
      ),
      CommunityPost(
        author: 'Priya Nair',
        role: 'Parent',
        timeAgo: '4d ago',
        title: 'Our mornings finally feel calmer',
        body: 'We moved the picture schedule to the fridge at eye-level. Two weeks in, fewer meltdowns before school. Small change, big shift.',
        likes: 64,
      ),
      CommunityPost(
        author: 'Dr. Alia Mehta',
        role: 'Developmental Pediatrician',
        timeAgo: '2d ago',
        title: 'Three small wins to notice this month',
        body: 'Small changes in communication, routine participation, and shared attention can all be meaningful progress.',
        likes: 89,
      ),
    ];
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore
          .collection('communityPosts')
          .orderBy('createdAt', descending: true)
          .get();

      final loadedPosts = snapshot.docs.map((doc) {
        final data = doc.data();

        final createdAt = data['createdAt'];
        String timeAgo = 'Just now';

        if (createdAt is Timestamp) {
          timeAgo = _formatTimeAgo(createdAt.toDate());
        }

        return CommunityPost(
          id: doc.id,
          author: (data['author'] ?? 'Parent').toString(),
          role: (data['role'] ?? 'Parent').toString(),
          timeAgo: timeAgo,
          title: (data['title'] ?? '').toString(),
          body: (data['body'] ?? '').toString(),
          likes: (data['likes'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _posts = loadedPosts.isEmpty ? _samplePosts() : loadedPosts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _posts = _samplePosts();
        _isLoading = false;
        _errorMessage = 'Could not load community posts.';
      });
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    if (difference.inDays < 30) {
      return '${difference.inDays ~/ 7}w ago';
    }

    if (difference.inDays < 365) {
      return '${difference.inDays ~/ 30}mo ago';
    }

    return '${difference.inDays ~/ 365}y ago';
  }

  Future<void> _openCreatePost() async {
    final result = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));

    if (!mounted) return;

    if (result is CommunityPost) {
      final user = _auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in before sharing a post.'),
          ),
        );
        return;
      }

      try {
        await _firestore.collection('communityPosts').add({
          'author': result.author,
          'role': 'Parent',
          'title': result.title,
          'body': result.body,
          'likes': 0,
          'authorUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _loadPosts();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your post was shared successfully.')),
        );
      } catch (_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share your post.')),
        );
      }
    }
  }

  void _openSpecialist(CommunitySpecialist specialist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityProfileScreen(
          name: specialist.name,
          role: specialist.role,
          bio: specialist.bio,
          distance: specialist.distance,
          rating: specialist.rating,
          isSpecialist: true,
        ),
      ),
    );
  }

  void _openPostAuthor(CommunityPost post) {
    final isSpecialist = post.role != 'Parent';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityProfileScreen(
          name: post.author,
          role: post.role,
          bio: isSpecialist
              ? 'Community specialist sharing practical guidance with parents and families.'
              : 'Parent sharing personal experiences and practical ideas with the community.',
          isSpecialist: isSpecialist,
        ),
      ),
    );
  }

  Future<void> _likePost(int index) async {
    final post = _posts[index];

    if (post.id == null) {
      setState(() {
        post.likes++;
      });
      return;
    }

    try {
      await _firestore.collection('communityPosts').doc(post.id).update({
        'likes': FieldValue.increment(1),
      });

      if (!mounted) return;

      setState(() {
        post.likes++;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not like this post.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      children: [
        const Text(
          'Community',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Stories and guidance from parents and verified specialists.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.inkSoft,
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          'SPECIALISTS NEAR YOU',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.inkSoft,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          height: 142,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _specialists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final specialist = _specialists[index];
              return _buildSpecialistCard(specialist);
            },
          ),
        ),

        const SizedBox(height: 26),

        Row(
          children: [
            const Expanded(
              child: Text(
                'STORIES & GUIDANCE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkSoft,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            TextButton.icon(
              onPressed: _openCreatePost,
              icon: const Icon(Icons.add, size: 18, color: AppColors.sageDark),
              label: const Text(
                'Share',
                style: TextStyle(
                  color: AppColors.sageDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No community posts yet.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
              ),
            ),
          )
        else
          ...List.generate(_posts.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPostCard(index),
            );
          }),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
            ),
          ),
      ],
    );
  }

  Widget _buildSpecialistCard(CommunitySpecialist specialist) {
    return InkWell(
      onTap: () => _openSpecialist(specialist),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.sageLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: AppColors.sageDark,
                    size: 22,
                  ),
                ),

                const Spacer(),

                const Icon(
                  Icons.verified_outlined,
                  color: AppColors.sageDark,
                  size: 17,
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              specialist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              specialist.role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
            ),

            const Spacer(),

            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.inkFaint,
                ),

                const SizedBox(width: 3),

                Text(
                  specialist.distance,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                  ),
                ),

                const SizedBox(width: 12),

                const Icon(
                  Icons.star_outline,
                  size: 14,
                  color: AppColors.goldDark,
                ),

                const SizedBox(width: 3),

                Text(
                  specialist.rating,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(int index) {
    final post = _posts[index];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _openPostAuthor(post),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.sageLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    post.role == 'Parent'
                        ? Icons.person_outline
                        : Icons.medical_services_outlined,
                    size: 19,
                    color: AppColors.sageDark,
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: post.author,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),

                        TextSpan(
                          text: '  ·  ${post.role}  ·  ${post.timeAgo}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Icon(
                  Icons.chevron_right,
                  size: 19,
                  color: AppColors.inkFaint,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Text(
            post.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            post.body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.inkSoft,
            ),
          ),

          const SizedBox(height: 9),

          InkWell(
            onTap: () => _likePost(index),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, size: 17, color: AppColors.coral),

                  const SizedBox(width: 5),

                  Text(
                    '${post.likes}',
                    style: const TextStyle(
                      color: AppColors.coral,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
