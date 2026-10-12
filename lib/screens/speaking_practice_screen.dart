import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../theme/app_colors.dart';

class SpeakingPracticeScreen extends StatefulWidget {
  final String childName;

  const SpeakingPracticeScreen({super.key, required this.childName});

  @override
  State<SpeakingPracticeScreen> createState() => _SpeakingPracticeScreenState();
}

class _SpeakingPracticeScreenState extends State<SpeakingPracticeScreen> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  final List<PracticeWord> _words = const [
    PracticeWord('Mom', '👩'),
    PracticeWord('Dad', '👨'),
    PracticeWord('Train', '🚂'),
    PracticeWord('Ball', '⚽'),
    PracticeWord('Water', '💧'),
    PracticeWord('Hello', '👋'),
  ];

  int _currentIndex = 0;
  int _stars = 0;

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _movingToNext = false;

  String _recognizedText = '';

  PracticeWord get _currentWord => _words[_currentIndex];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (_) {
          if (!mounted) return;

          setState(() {
            _isListening = false;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _speechAvailable = available;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _speechAvailable = false;
      });
    }
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.4);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (_) {}
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;

    setState(() {
      _isListening = status == 'listening';
    });

    if (status == 'done' || status == 'notListening') {
      Future.delayed(const Duration(milliseconds: 150), _checkRecognizedWord);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;

    setState(() {
      _recognizedText = result.recognizedWords.trim();
    });

    if (result.finalResult) {
      Future.delayed(const Duration(milliseconds: 100), _checkRecognizedWord);
    }
  }

  Future<void> _startListening() async {
    if (_movingToNext) return;

    if (_isListening) {
      await _speech.stop();
      return;
    }

    if (!_speechAvailable) {
      _showMessage(
        'Speech recognition is not available. Please allow microphone access.',
      );
      return;
    }

    await _tts.stop();

    setState(() {
      _recognizedText = '';
      _isListening = true;
    });

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 6),
          pauseFor: const Duration(seconds: 2),
          partialResults: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _checkRecognizedWord() async {
    if (_movingToNext) return;

    final spoken = _normalize(_recognizedText);

    if (spoken.isEmpty) return;

    final target = _normalize(_currentWord.word);

    final correct = _isCorrect(spoken, target);

    if (correct) {
      await _speech.stop();
      await _tts.stop();

      if (!mounted) return;

      _movingToNext = true;

      setState(() {
        _isListening = false;
        _stars++;
      });

      _showMessage('Great job! ⭐');

      Future.delayed(const Duration(milliseconds: 800), _nextWord);
    } else {
      if (!mounted) return;

      setState(() {
        _isListening = false;
      });

      _showMessage('Good try! Say "${_currentWord.word}" again.');
    }
  }

  bool _isCorrect(String spoken, String target) {
    if (spoken == target) {
      return true;
    }

    if (spoken.contains(target)) {
      return true;
    }

    // Common pronunciation/recognition alternative.
    if (target == 'mom' &&
        (spoken.contains('mum') || spoken.contains('mommy'))) {
      return true;
    }

    if (target == 'dad' &&
        (spoken.contains('daddy') || spoken.contains('dead'))) {
      return true;
    }

    if (target == 'hello' && spoken.contains('hi')) {
      return true;
    }

    return false;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _nextWord() {
    if (!mounted) return;

    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
        _recognizedText = '';
        _isListening = false;
      });

      _movingToNext = false;
    } else {
      _showFinishedDialog();
    }
  }

  void _skipWord() {
    if (_movingToNext) return;

    _speech.stop();

    setState(() {
      _recognizedText = '';
      _isListening = false;
    });

    _movingToNext = true;

    Future.delayed(const Duration(milliseconds: 150), _nextWord);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _showFinishedDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Great work! 🎉'),
          content: Text(
            '${widget.childName} finished speaking practice.\n\n'
            'Stars earned: $_stars',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                setState(() {
                  _currentIndex = 0;
                  _stars = 0;
                  _recognizedText = '';
                  _isListening = false;
                });

                _movingToNext = false;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sage,
                foregroundColor: Colors.white,
              ),
              child: const Text('Practice again'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _hearWord() async {
    try {
      await _tts.stop();
      await _tts.speak(_currentWord.word);
    } catch (_) {}
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _buildProgress(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 25),

                    _buildCharacter(),

                    const SizedBox(height: 25),

                    _buildWordCard(),

                    const SizedBox(height: 18),

                    _buildHearButton(),

                    const SizedBox(height: 24),

                    _buildMicrophone(),

                    const SizedBox(height: 12),

                    Text(
                      _isListening
                          ? 'Listening...'
                          : 'Tap the mic and say the word',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.inkSoft,
                      ),
                    ),

                    if (_recognizedText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'I heard: $_recognizedText',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.sageDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Fallback button so the child can
                    // always move to the next word.
                    TextButton(
                      onPressed: _skipWord,
                      child: const Text(
                        'Next word',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          ),

          const Expanded(
            child: Text(
              'Say it with me!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),

          Row(
            children: [
              const Icon(Icons.star, size: 18, color: AppColors.goldDark),
              const SizedBox(width: 3),
              Text(
                '$_stars',
                style: const TextStyle(
                  color: AppColors.goldDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 38),
      child: Row(
        children: List.generate(_words.length, (index) {
          final active = index <= _currentIndex;

          return Expanded(
            child: Container(
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? AppColors.sage : AppColors.sageLight,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCharacter() {
    return Container(
      width: 112,
      height: 112,
      decoration: const BoxDecoration(
        color: AppColors.sageLight,
        shape: BoxShape.circle,
      ),
      child: const Center(child: Text('🐼', style: TextStyle(fontSize: 66))),
    );
  }

  Widget _buildWordCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          Text(_currentWord.emoji, style: const TextStyle(fontSize: 42)),
          const SizedBox(height: 8),
          Text(
            _currentWord.word,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHearButton() {
    return OutlinedButton.icon(
      onPressed: _hearWord,
      icon: const Icon(Icons.volume_up_outlined, size: 19),
      label: const Text('Hear it'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.sageDark,
        backgroundColor: AppColors.sageLight,
        side: const BorderSide(color: AppColors.sage),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildMicrophone() {
    return GestureDetector(
      onTap: _startListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: _isListening ? AppColors.sage : AppColors.goldSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
          size: 38,
          color: _isListening ? Colors.white : AppColors.goldDark,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomItem(Icons.chat_bubble_outline_rounded, 'Chat'),
          _bottomItem(Icons.show_chart_rounded, 'Activities', active: true),
          _bottomItem(Icons.groups_outlined, 'Community'),
          _bottomItem(Icons.trending_up_rounded, 'Progress'),
        ],
      ),
    );
  }

  Widget _bottomItem(IconData icon, String label, {bool active = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 22,
          color: active ? AppColors.sageDark : AppColors.inkFaint,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.sageDark : AppColors.inkFaint,
          ),
        ),
      ],
    );
  }
}

class PracticeWord {
  final String word;
  final String emoji;

  const PracticeWord(this.word, this.emoji);
}
