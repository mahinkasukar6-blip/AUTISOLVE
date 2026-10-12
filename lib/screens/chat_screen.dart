import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String childName;
  final String? initialChatId;

  const ChatScreen({super.key, required this.childName, this.initialChatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color _pageColor = Color(0xFFF7FAF0);
  static const Color _userColor = Color(0xFFB8EDB6);
  static const Color _assistantColor = Color(0xFFE5E8DF);
  static const Color _green = Color(0xFF329A4A);
  static const Color _darkGreen = Color(0xFF246B38);
  static const Color _linkBlue = Color(0xFF1769AA);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final List<_ChatMessage> _messages = [];

  User? get _user => FirebaseAuth.instance.currentUser;

  String? _chatId;
  String? _attachmentName;
  String? _attachmentMime;
  String? _attachmentBase64;
  String? _speakingMessage;

  bool _loading = false;
  bool _speechAvailable = false;
  bool _listening = false;
  bool _thinkMode = false;
  bool _webSearch = false;

  @override
  void initState() {
    super.initState();
    _initializeVoice();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final id = widget.initialChatId;

      if (id != null && id.isNotEmpty) {
        _loadChat(id);
      } else {
        _startNewChat();
      }
    });
  }

  Future<void> _initializeVoice() async {
    try {
      _speechAvailable = await _speech.initialize();

      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _speakingMessage = null);
        }
      });

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Voice initialization error: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearAttachment() {
    _attachmentName = null;
    _attachmentMime = null;
    _attachmentBase64 = null;
  }

  Future<void> _openSourceLink(String? href) async {
    if (href == null || href.trim().isEmpty) return;

    final uri = Uri.tryParse(href.trim());

    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      _showMessage('This source link is not valid.');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        _showMessage('Could not open this source link.');
      }
    } catch (e) {
      debugPrint('Open source link error: $e');

      if (mounted) {
        _showMessage('Could not open this source link.');
      }
    }
  }

  Future<void> _startNewChat() async {
    final user = _user;

    if (user == null) {
      _showMessage('Please sign in to use AUTISOLVE.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _chatId = null;
      _messages.clear();
      _clearAttachment();
      _thinkMode = false;
      _webSearch = false;
    });

    try {
      final id = await _chatService.createChat(
        uid: user.uid,
        childName: widget.childName,
      );

      if (!mounted) return;
      setState(() => _chatId = id);
    } catch (e) {
      debugPrint('Create chat error: $e');
      _showMessage('Could not create a new chat. Check your connection.');
    }
  }

  Future<void> _deleteChat(String chatId, String title) async {
    final user = _user;

    if (user == null) {
      _showMessage('Please sign in to delete chats.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          'Delete "$title" and all its messages? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .doc(chatId);

      while (true) {
        final snapshot = await chatRef.collection('messages').limit(400).get();

        if (snapshot.docs.isEmpty) break;

        final batch = FirebaseFirestore.instance.batch();

        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
      }

      await chatRef.delete();

      if (!mounted) return;

      if (_chatId == chatId) {
        setState(() {
          _chatId = null;
          _messages.clear();
        });

        await _startNewChat();
      }

      _showMessage('Chat deleted successfully.');
    } catch (e) {
      debugPrint('Delete chat error: $e');
      _showMessage('Could not delete chat. Please try again.');
    }
  }

  Future<void> _openChatHistory() async {
    final user = _user;

    if (user == null) {
      _showMessage('Please sign in to view your chat history.');
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .get();

      if (!mounted) return;

      final chats = snapshot.docs.toList()
        ..sort((a, b) {
          final aDate = a.data()['updatedAt'];
          final bDate = b.data()['updatedAt'];

          final aTime = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
          final bTime = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;

          return bTime.compareTo(aTime);
        });

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.70,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Chat history',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: chats.isEmpty
                      ? const Center(child: Text('No previous chats yet.'))
                      : ListView.builder(
                          itemCount: chats.length,
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            final title =
                                chat.data()['title'] as String? ?? 'New chat';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              leading: const Icon(Icons.chat_bubble_outline),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(widget.childName),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _loadChat(chat.id);
                              },
                              trailing: SizedBox(
                                width: 48,
                                child: PopupMenuButton<String>(
                                  tooltip: 'Chat options',
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      Navigator.pop(sheetContext);
                                      _deleteChat(chat.id, title);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 10),
                                          Text('Delete chat'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _startNewChat();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('New chat'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Chat history error: $e');
      _showMessage('Could not load chat history.');
    }
  }

  Future<void> _loadChat(String chatId) async {
    final user = _user;

    if (user == null || _loading) return;

    setState(() {
      _chatId = chatId;
      _messages.clear();
      _loading = true;
      _clearAttachment();
    });

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .doc(chatId);

      final chatSnapshot = await chatRef.get();

      if (!chatSnapshot.exists) {
        throw Exception('Saved chat does not exist.');
      }

      final snapshot = await chatRef.collection('messages').get();

      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final aDate = a.data()['createdAt'];
          final bDate = b.data()['createdAt'];

          final aTime = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
          final bTime = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;

          return aTime.compareTo(bTime);
        });

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(
            docs.map((doc) {
              final data = doc.data();

              return _ChatMessage(
                text: data['text']?.toString() ?? '',
                fromUser: data['fromUser'] == true,
              );
            }),
          );
      });

      _scrollToBottom();

      if (_messages.isEmpty) {
        _showMessage('This chat has no saved messages.');
      }
    } catch (e) {
      debugPrint('Load chat error: $e');
      _showMessage('Could not load this chat. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveMessage(_ChatMessage message) async {
    final user = _user;
    final id = _chatId;

    if (user == null || id == null) return;

    try {
      await _chatService.saveMessage(
        uid: user.uid,
        chatId: id,
        text: message.text,
        fromUser: message.fromUser,
      );
    } catch (e) {
      debugPrint('Save message error: $e');
      _showMessage('Message could not be saved to chat history.');
    }
  }

  // Loads profile, report metadata, and recent activity data.

  Future<Map<String, dynamic>> _loadChildContext() async {
    final user = _user;
    if (user == null) return {};

    try {
      // 1. Load the child's saved profile.
      final profileSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('childProfiles')
          .doc('main')
          .get();

      final profile = profileSnapshot.data() ?? <String, dynamic>{};

      // 2. Fetch activities using only parentUid.
      // This avoids the composite-index error from the previous query.
      final activitySnapshot = await FirebaseFirestore.instance
          .collection('activityCompletions')
          .where('parentUid', isEqualTo: user.uid)
          .get();

      // 3. Filter by child name and the last seven days in Dart.
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final activities = activitySnapshot.docs
          .where((doc) {
            final data = doc.data();

            final activityChildName = (data['childName'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

            final selectedChildName = widget.childName.trim().toLowerCase();

            if (activityChildName != selectedChildName) {
              return false;
            }

            final completedAt = data['completedAt'];

            if (completedAt is! Timestamp) {
              return false;
            }

            return completedAt.toDate().isAfter(sevenDaysAgo);
          })
          .map((doc) {
            final data = doc.data();
            final completedAt = data['completedAt'];

            return <String, dynamic>{
              'activityName':
                  data['activityName'] ??
                  data['activityTitle'] ??
                  data['title'] ??
                  data['activityId'] ??
                  'Completed activity',
              'completedAt': completedAt is Timestamp
                  ? completedAt.toDate().toIso8601String()
                  : null,
            };
          })
          .toList();

      // 4. Send the profile, activities, and report metadata to the Worker.
      final contextData = <String, dynamic>{
        'childName': profile['childName'] ?? widget.childName,
        'age': profile['age'],
        'gender': profile['gender'],
        'supportAreas': profile['supportAreas'],
        'notes': profile['notes'],
        'languageCode': profile['languageCode'],
        'recentActivityPeriodDays': 7,
        'recentCompletedActivityCount': activities.length,
        'recentCompletedActivities': activities,
        'reportFileUrl': profile['reportFileUrl'],
        'reportFileName': profile['reportFileName'],
        'reportStorage': profile['reportStorage'],
      };

      // Remove empty optional values.
      contextData.removeWhere((key, value) => value == null || value == '');

      debugPrint(
        'AUTISOLVE: Child profile loaded. '
        'Report URL present: '
        '${profile['reportFileUrl'] is String && (profile['reportFileUrl'] as String).isNotEmpty}',
      );

      debugPrint('AUTISOLVE: Recent activities found: ${activities.length}');

      debugPrint('AUTISOLVE: Child context loaded successfully.');

      return contextData;
    } catch (e) {
      debugPrint('AUTISOLVE: Could not load child context: $e');
      return {};
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if ((text.isEmpty && _attachmentBase64 == null) || _loading) {
      return;
    }

    if (_user == null) {
      _showMessage('Please sign in to use AUTISOLVE.');
      return;
    }

    if (_chatId == null) {
      await _startNewChat();
      if (_chatId == null) return;
    }

    if (_listening) await _speech.stop();
    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _listening = false;
      _speakingMessage = null;
    });

    final messageText = text.isEmpty
        ? 'Please help me with this attachment.'
        : text;

    final attachmentName = _attachmentName;
    final attachmentMime = _attachmentMime;
    final attachmentBase64 = _attachmentBase64;

    final userMessage = _ChatMessage(
      text: attachmentName == null
          ? messageText
          : '$messageText\n\nAttachment: $attachmentName',
      fromUser: true,
    );

    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _clearAttachment();
      _loading = true;
    });

    await _saveMessage(userMessage);
    _scrollToBottom();

    try {
      final childContext = await _loadChildContext();

      final reply = await _chatService.sendMessage(
        message: messageText,
        childName: widget.childName,
        mode: _thinkMode ? 'think' : 'normal',
        webSearch: _webSearch,
        childContext: childContext,
        attachment: attachmentBase64 != null && attachmentName != null
            ? {
                'name': attachmentName,
                'mimeType': attachmentMime ?? 'application/octet-stream',
                'base64': attachmentBase64,
              }
            : null,
      );

      if (!mounted) return;

      final assistantMessage = _ChatMessage(text: reply, fromUser: false);

      setState(() => _messages.add(assistantMessage));

      await _saveMessage(assistantMessage);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Chat request error: $e');

      if (mounted) {
        final errorMessage = _ChatMessage(
          text: 'Sorry, I could not get a response. Please try again.',
          fromUser: false,
        );

        setState(() => _messages.add(errorMessage));
        await _saveMessage(errorMessage);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAttachment({required bool imageOnly}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: imageOnly ? FileType.image : FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null) {
        _showMessage('Could not read that file.');
        return;
      }

      if (bytes.length > 3 * 1024 * 1024) {
        _showMessage('Please choose a file smaller than 3 MB.');
        return;
      }

      final extension = file.extension?.toLowerCase() ?? '';

      final mime = switch (extension) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        'txt' => 'text/plain',
        _ => 'application/octet-stream',
      };

      if (!mounted) return;

      setState(() {
        _attachmentName = file.name;
        _attachmentMime = mime;
        _attachmentBase64 = base64Encode(bytes);
      });
    } catch (e) {
      debugPrint('Attachment error: $e');
      _showMessage('Could not select that file.');
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      _showMessage('Speech recognition is not available on this device.');
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    await _tts.stop();

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
          });
        },
      );

      if (mounted) setState(() => _listening = true);
    } catch (e) {
      debugPrint('Speech recognition error: $e');
      _showMessage('Could not start the microphone.');
    }
  }

  Future<void> _speakMessage(String text) async {
    try {
      if (_speakingMessage == text) {
        await _tts.stop();
        if (mounted) setState(() => _speakingMessage = null);
        return;
      }

      await _tts.stop();

      if (!mounted) return;

      setState(() => _speakingMessage = text);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Text-to-speech error: $e');
      if (mounted) setState(() => _speakingMessage = null);
    }
  }

  void _showPlusMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _pageColor,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add to your message',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAttachment(imageOnly: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAttachment(imageOnly: false);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.psychology_outlined,
                color: _thinkMode ? _green : null,
              ),
              title: const Text('Think'),
              subtitle: const Text('Ask for a more considered answer'),
              trailing: _thinkMode
                  ? const Icon(Icons.check_circle, color: _green)
                  : null,
              onTap: () {
                setState(() => _thinkMode = !_thinkMode);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: Icon(Icons.language, color: _webSearch ? _green : null),
              title: const Text('Web Search'),
              subtitle: const Text('Request up-to-date information'),
              trailing: _webSearch
                  ? const Icon(Icons.check_circle, color: _green)
                  : null,
              onTap: () {
                setState(() => _webSearch = !_webSearch);
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Chat history'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openChatHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text('New chat'),
              onTap: () {
                Navigator.pop(sheetContext);
                _startNewChat();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: _pageColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('AUTISOLVE Assistant'),
        actions: [
          IconButton(
            tooltip: 'Chat history',
            onPressed: _openChatHistory,
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: _startNewChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'More options',
            onPressed: _showMoreOptions,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty && !_loading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite_border,
                              size: 46,
                              color: _green,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'How can I help you today?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Support for ${widget.childName}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }

                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            if (_thinkMode || _webSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      if (_thinkMode)
                        InputChip(
                          avatar: const Icon(
                            Icons.psychology_outlined,
                            size: 18,
                          ),
                          label: const Text('Think'),
                          onDeleted: () {
                            setState(() => _thinkMode = false);
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      if (_webSearch)
                        InputChip(
                          avatar: const Icon(Icons.language, size: 18),
                          label: const Text('Web Search'),
                          onDeleted: () {
                            setState(() => _webSearch = false);
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ),
            if (_attachmentName != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFDCE2D5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _attachmentName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remove attachment',
                      onPressed: () {
                        setState(_clearAttachment);
                      },
                      icon: const Icon(Icons.close, size: 19),
                    ),
                  ],
                ),
              ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.fromUser;
    final isSpeaking = !isUser && _speakingMessage == message.text;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUser ? _userColor : _assistantColor,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: isUser
                    ? SelectableText(
                        message.text,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.42,
                          color: Color(0xFF202820),
                        ),
                      )
                    : MarkdownBody(
                        data: message.text,
                        selectable: true,
                        onTapLink: (text, href, title) {
                          _openSourceLink(href);
                        },
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(Theme.of(context))
                                .copyWith(
                                  p: const TextStyle(
                                    fontSize: 15.5,
                                    height: 1.5,
                                    color: Color(0xFF202820),
                                  ),
                                  h1: const TextStyle(
                                    fontSize: 21,
                                    height: 1.35,
                                    fontWeight: FontWeight.bold,
                                    color: _green,
                                  ),
                                  h2: const TextStyle(
                                    fontSize: 19,
                                    height: 1.35,
                                    fontWeight: FontWeight.bold,
                                    color: _green,
                                  ),
                                  h3: const TextStyle(
                                    fontSize: 17,
                                    height: 1.4,
                                    fontWeight: FontWeight.bold,
                                    color: _green,
                                  ),
                                  strong: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _darkGreen,
                                  ),
                                  em: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF475448),
                                  ),
                                  a: const TextStyle(
                                    color: _linkBlue,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  code: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8A3D8F),
                                    backgroundColor: Color(0xFFF0EAF3),
                                  ),
                                  blockquote: const TextStyle(
                                    color: Color(0xFF4F6250),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  listBullet: const TextStyle(
                                    fontSize: 15.5,
                                    height: 1.5,
                                    color: _green,
                                  ),
                                  blockquoteDecoration: BoxDecoration(
                                    color: const Color(0xFFF2F6ED),
                                    border: const Border(
                                      left: BorderSide(color: _green, width: 3),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  blockquotePadding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    8,
                                    8,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: const Color(0xFFF0EAF3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  codeblockPadding: const EdgeInsets.all(12),
                                  horizontalRuleDecoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Color(0xFFD0D9CA)),
                                    ),
                                  ),
                                ),
                      ),
              ),
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(left: 3, top: 3),
                  child: IconButton(
                    tooltip: isSpeaking
                        ? 'Stop reading'
                        : 'Read response aloud',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 38,
                    ),
                    onPressed: () => _speakMessage(message.text),
                    icon: Icon(
                      isSpeaking
                          ? Icons.stop_circle_outlined
                          : Icons.volume_up_outlined,
                      size: 23,
                      color: const Color(0xFF48564A),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: _pageColor,
        border: Border(top: BorderSide(color: Color(0xFFE7EBDD), width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Photo, file, Think and Web Search',
              onPressed: _showPlusMenu,
              icon: const Icon(Icons.add, size: 27),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE0E5DA)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask AUTISOLVE...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _listening
                        ? 'Stop microphone'
                        : 'Speak your message',
                    onPressed: _toggleListening,
                    icon: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: _listening ? Colors.red : const Color(0xFF4D594E),
                      size: 23,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Material(
            color: _green,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Send message',
              onPressed: _loading ? null : _send,
              color: Colors.white,
              iconSize: 26,
              icon: const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool fromUser;

  const _ChatMessage({required this.text, required this.fromUser});
}
