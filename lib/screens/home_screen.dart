import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';
import 'chat_screen.dart';
import 'activity_screen.dart';
import 'community_screen.dart';
import 'progress_screen.dart';
import 'community_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String childName;
  final String languageCode;

  const HomeScreen({
    super.key,
    required this.childName,
    this.languageCode = 'en',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  final List<String> _titles = [
    'Companion Chat',
    "Today's activities",
    'Community',
    'Progress',
  ];

  final List<String> _quickTopics = [
    'Bedtime routine ideas',
    'Handling loud environments',
    'Speech milestones at 5',
    'School transition tips',
  ];

  void _changeTab(int index) {
    setState(() {
      _selectedTab = index;
    });
  }

  void _openParentProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CommunityProfileScreen(
          name: 'Parent Account',
          role: 'Parent',
          bio: 'A parent using Autisolve to support their child and share experiences with other families.',
          isSpecialist: false,
        ),
      ),
    );
  }

  void _selectTopic(String topic) {
    Navigator.of(context).pop();

    setState(() {
      _selectedTab = 0;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Topic selected: $topic')));
  }

  void _startNewChat() {
    Navigator.of(context).pop();

    setState(() {
      _selectedTab = 0;
    });
  }

  void _openSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings will be added here.')),
    );
  }

  void _openSavedChat(String chatId) {
    Navigator.of(context).pop();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(childName: widget.childName, initialChatId: chatId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: AppColors.ink, size: 26),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.sageDark, size: 19),
            const SizedBox(width: 6),
            Text(
              _titles[_selectedTab],
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: _openParentProfile,
              borderRadius: BorderRadius.circular(24),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.goldSoft,
                child: Text(
                  'P',
                  style: TextStyle(
                    color: AppColors.goldDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          ChatScreen(childName: widget.childName),
          ActivitiesScreen(childName: widget.childName),
          const CommunityScreen(),
          ProgressScreen(childName: widget.childName),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: _changeTab,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.sageDark,
        unselectedItemColor: AppColors.inkFaint,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_rounded),
            activeIcon: Icon(Icons.show_chart_rounded),
            label: 'Activities',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups_rounded),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_rounded),
            activeIcon: Icon(Icons.trending_up_rounded),
            label: 'Progress',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.80,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chats & Topics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startNewChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sageLight,
                    foregroundColor: AppColors.sageDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'New chat session',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: AppColors.inkFaint),
                  SizedBox(width: 8),
                  Text(
                    'Suggested quick topics',
                    style: TextStyle(fontSize: 13, color: AppColors.inkFaint),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            ..._quickTopics.map((topic) {
              return ListTile(
                title: Text(topic),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.inkFaint,
                ),
                onTap: () => _selectTopic(topic),
              );
            }),

            const Divider(color: AppColors.border),

            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent chats',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ),

            Expanded(
              child: user == null
                  ? const Center(
                      child: Text('Please sign in to view your chats.'),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('chats')
                          .orderBy('updatedAt', descending: true)
                          .limit(10)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Could not load chat history.'),
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final chats = snapshot.data?.docs ?? [];

                        if (chats.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No saved chats yet. Start a new chat!',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: chats.length,
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            final data = chat.data();
                            final title =
                                data['title'] as String? ?? 'New chat';

                            return ListTile(
                              leading: const Icon(
                                Icons.chat_bubble_outline,
                                size: 19,
                                color: AppColors.sageDark,
                              ),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.inkFaint,
                              ),
                              onTap: () => _openSavedChat(chat.id),
                            );
                          },
                        );
                      },
                    ),
            ),

            const Divider(color: AppColors.border),

            InkWell(
              onTap: _openParentProfile,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.goldSoft,
                      child: Text(
                        'P',
                        style: TextStyle(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Parent account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Caring for ${widget.childName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openSettings,
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: AppColors.inkFaint,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.inkFaint),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
