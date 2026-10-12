import 'package:flutter/material.dart';

import 'report_upload_screen.dart';
import '../theme/app_colors.dart';

class AppLanguage {
  final String code;
  final String native;
  final String english;

  const AppLanguage({
    required this.code,
    required this.native,
    required this.english,
  });
}

const List<AppLanguage> kLanguages = [
  AppLanguage(code: 'en', native: 'English', english: 'English'),
  AppLanguage(code: 'mr', native: 'मराठी', english: 'Marathi'),
  AppLanguage(code: 'hi', native: 'हिंदी', english: 'Hindi'),
  AppLanguage(code: 'ur', native: 'اردو', english: 'Urdu'),
  AppLanguage(code: 'kn', native: 'ಕನ್ನಡ', english: 'Kannada'),
];

class LanguageSelectScreen extends StatefulWidget {
  final String initialCode;
  final void Function(String languageCode) onContinue;

  const LanguageSelectScreen({
    super.key,
    this.initialCode = 'en',
    required this.onContinue,
  });

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCode;
  }

  void _continueToReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportUploadScreen(languageCode: _selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.public,
                  color: AppColors.sageDark,
                  size: 26,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Choose your language',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'The app and your chatbot will respond in this language.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.inkSoft,
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: ListView.separated(
                  itemCount: kLanguages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final language = kLanguages[index];

                    final selected = language.code == _selected;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selected = language.code;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.sageLight : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? AppColors.sage : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    language.native,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? AppColors.sageDark
                                          : AppColors.ink,
                                    ),
                                  ),
                                  if (language.native != language.english)
                                    Text(
                                      language.english,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.inkFaint,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check,
                                color: AppColors.sageDark,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continueToReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
