import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'child_profile_screen.dart';
import '../theme/app_colors.dart';

class ReportUploadScreen extends StatefulWidget {
  final String languageCode;

  const ReportUploadScreen({super.key, this.languageCode = 'en'});

  @override
  State<ReportUploadScreen> createState() => _ReportUploadScreenState();
}

class _ReportUploadScreenState extends State<ReportUploadScreen> {
  // IMPORTANT:
  // Replace this with your Cloudinary Cloud Name.
  // Example: 'dxxxxxxx'
  static const String _cloudName = 'ivghfrnq';

  // This is the unsigned preset we created.
  static const String _uploadPreset = 'autisolve_report_upload';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fileName;
  String? _uploadedUrl;
  String? _uploadedPublicId;

  bool _isPicking = false;
  bool _isUploading = false;

  Future<void> _pickReport() async {
    if (_isPicking || _isUploading) return;

    setState(() {
      _isPicking = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;

      if (file.bytes == null && file.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected file.')),
        );
        return;
      }

      setState(() {
        _fileName = file.name;
        _uploadedUrl = null;
        _uploadedPublicId = null;
      });

      await _uploadToCloudinary(file);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _uploadedUrl = null;
        _uploadedPublicId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload the report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _uploadToCloudinary(PlatformFile file) async {
    if (_cloudName == 'YOUR_CLOUD_NAME') {
      throw Exception('Cloudinary cloud name is not configured yet.');
    }

    setState(() {
      _isUploading = true;
    });

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload',
    );

    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = _uploadPreset;

    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
      );
    } else if (file.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ),
      );
    } else {
      throw Exception('The selected file could not be read.');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    Map<String, dynamic>? responseData;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        responseData = decoded;
      }
    } catch (_) {
      responseData = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final cloudinaryMessage = responseData?['error']?['message']?.toString();

      throw Exception(
        cloudinaryMessage ??
            'Cloudinary upload failed (${response.statusCode}).',
      );
    }

    final secureUrl = responseData?['secure_url']?.toString();
    final publicId = responseData?['public_id']?.toString();

    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Cloudinary did not return a file URL.');
    }

    setState(() {
      _uploadedUrl = secureUrl;
      _uploadedPublicId = publicId;
    });

    await _saveReportToFirestore(
      fileName: file.name,
      secureUrl: secureUrl,
      publicId: publicId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report uploaded successfully.')),
    );
  }

  Future<void> _saveReportToFirestore({
    required String fileName,
    required String secureUrl,
    String? publicId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please sign in before uploading a report.');
    }

    final profileRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('childProfiles')
        .doc('main');

    await profileRef.set({
      'uid': user.uid,
      'reportFileName': fileName,
      'reportFileUrl': secureUrl,
      'reportPublicId': publicId,
      'reportStorage': 'cloudinary',
      'reportUploadedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _continueToProfile() {
    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the report upload to finish.'),
        ),
      );
      return;
    }

    if (_fileName != null && _uploadedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload the report successfully first.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChildProfileScreen(
          reportFileName: _fileName,
          languageCode: widget.languageCode,
        ),
      ),
    );
  }

  void _skipForNow() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChildProfileScreen(languageCode: widget.languageCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Let's personalize things",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Upload your child\'s report if you have one. '
                'This is optional and can be skipped for now.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.inkSoft,
                ),
              ),

              const SizedBox(height: 28),

              GestureDetector(
                onTap: (_isPicking || _isUploading) ? null : _pickReport,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 36,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.sage, width: 1.8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _fileName == null
                            ? Icons.cloud_upload_outlined
                            : _uploadedUrl != null
                            ? Icons.check_circle_outline
                            : Icons.insert_drive_file_outlined,
                        size: 42,
                        color: AppColors.sageDark,
                      ),

                      const SizedBox(height: 14),

                      Text(
                        _fileName == null ? 'Upload child report' : _fileName!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'PDF, JPG, JPEG or PNG',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),

                      const SizedBox(height: 18),

                      if (_isPicking || _isUploading)
                        const Column(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Uploading report...',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        )
                      else if (_uploadedUrl != null)
                        const Text(
                          'Report uploaded successfully',
                          style: TextStyle(
                            color: AppColors.sageDark,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sageLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Choose file',
                            style: TextStyle(
                              color: AppColors.sageDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continueToProfile,
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
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isUploading ? null : _skipForNow,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
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
