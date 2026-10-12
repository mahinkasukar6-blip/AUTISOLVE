import 'dart:async';

import 'package:flutter/material.dart';

import 'home_screen.dart';
import '../theme/app_colors.dart';

class PersonalizingScreen extends StatefulWidget {
  final String childName;
  final String languageCode;

  const PersonalizingScreen({
    super.key,
    required this.childName,
    required this.languageCode,
  });

  @override
  State<PersonalizingScreen> createState() => _PersonalizingScreenState();
}

class _PersonalizingScreenState extends State<PersonalizingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 2), _openHome);
  }

  void _openHome() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          childName: widget.childName,
          languageCode: widget.languageCode,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.sageLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.sageDark,
                size: 34,
              ),
            ),

            const SizedBox(height: 24),

            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                color: AppColors.sage,
                strokeWidth: 3,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Personalizing your chatbot for ${widget.childName}...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
