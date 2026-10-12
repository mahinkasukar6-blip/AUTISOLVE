import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'personalizing_screen.dart';
import '../theme/app_colors.dart';

class ChildProfileScreen extends StatefulWidget {
  final String? reportFileName;
  final String languageCode;

  const ChildProfileScreen({
    super.key,
    this.reportFileName,
    this.languageCode = 'en',
  });

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _ageController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _gender = 'Boy';

  final Set<String> _supportAreas = {'Communication', 'Sensory needs'};

  bool _isSaving = false;

  final List<String> _genderOptions = ['Boy', 'Girl', 'Prefer not to say'];

  final List<String> _supportOptions = [
    'Communication',
    'Social skills',
    'Sensory needs',
    'Routines & transitions',
    'Emotional regulation',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileAndContinue() async {
    final String name = _nameController.text.trim();

    final int? age = int.tryParse(_ageController.text.trim());

    final String notes = _notesController.text.trim();

    if (name.isEmpty) {
      _showMessage('Please enter your child\'s name.');
      return;
    }

    if (age == null || age <= 0) {
      _showMessage('Please enter a valid age.');
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Your login session has expired. Please sign in again.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String uid = user.uid;

      final DocumentReference<Map<String, dynamic>> profileRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('childProfiles')
          .doc('main');

      await profileRef.set({
        'uid': uid,
        'parentEmail': user.email,
        'childName': name,
        'age': age,
        'gender': _gender,
        'supportAreas': _supportAreas.toList(),
        'notes': notes,
        'languageCode': widget.languageCode,
        'reportFileName': widget.reportFileName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PersonalizingScreen(
            childName: name,
            languageCode: widget.languageCode,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showMessage('Could not save the profile. Please try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleSupportArea(String area) {
    setState(() {
      if (_supportAreas.contains(area)) {
        _supportAreas.remove(area);
      } else {
        _supportAreas.add(area);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                children: [
                  const Text(
                    'Tell us about your child',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'A few quick questions so responses feel relevant to your family.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.inkSoft,
                    ),
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    'Child\'s name',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),

                  const SizedBox(height: 8),

                  _buildTextField(
                    controller: _nameController,
                    hintText: 'Aarav',
                    textCapitalization: TextCapitalization.words,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Age',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),

                  const SizedBox(height: 8),

                  _buildTextField(
                    controller: _ageController,
                    hintText: '5',
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Gender',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _genderOptions.map((option) {
                      final bool selected = _gender == option;

                      return _SelectionChip(
                        label: option,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            _gender = option;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'What would you like support with?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _supportOptions.map((option) {
                      return _SelectionChip(
                        label: option,
                        selected: _supportAreas.contains(option),
                        onTap: () {
                          _toggleSupportArea(option);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Anything else the chatbot should know?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Gets overwhelmed by loud noises in crowded rooms, loves toy trains.',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.inkSoft,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.sage,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfileAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.sage.withValues(
                      alpha: 0.6,
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Personalize my chatbot',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.chevron_right, size: 19),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.sage, width: 1.5),
        ),
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.sageLight : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.sage : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.sageDark : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
