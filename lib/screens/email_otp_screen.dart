import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

import '../theme/app_colors.dart';
import 'language_select_screen.dart';
import 'report_upload_screen.dart';

class EmailOtpScreen extends StatefulWidget {
  final String email;

  const EmailOtpScreen({super.key, required this.email});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  static const String _backendUrl =
      'https://autisolve-otp.mahinkasukar6.workers.dev';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  late final TextEditingController _emailController;
  final TextEditingController _otpController = TextEditingController();

  Timer? _timer;

  int _secondsRemaining = 0;

  bool _isSending = false;
  bool _isVerifying = false;
  bool _hasSentCode = false;

  @override
  void initState() {
    super.initState();

    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();

    setState(() {
      _secondsRemaining = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining <= 1) {
        timer.cancel();

        setState(() {
          _secondsRemaining = 0;
        });

        return;
      }

      setState(() {
        _secondsRemaining--;
      });
    });
  }

  Future<String?> _getFirebaseIdToken() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    return user.getIdToken(true);
  }

  Future<void> _sendOtp() async {
    final String email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showMessage('Please enter an email address.');
      return;
    }

    final bool validEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        .hasMatch(email);

    if (!validEmail) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    if (_isSending) {
      return;
    }

    if (_secondsRemaining > 0 && _hasSentCode) {
      _showMessage(
        'Please wait $_secondsRemaining seconds before requesting another code.',
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final String? idToken = await _getFirebaseIdToken();

      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          _showMessage(
            'Your Google sign-in session has expired. Please sign in again.',
          );
        }
        return;
      }

      final response = await http.post(
        Uri.parse('$_backendUrl/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'email': email}),
      );

      Map<String, dynamic> data = {};

      try {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = {};
      }

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200 && data['ok'] == true) {
        _otpController.clear();

        setState(() {
          _hasSentCode = true;
          _emailController.text = email;
        });

        _startCountdown();

        _showMessage('Verification code sent to $email.');

        return;
      }

      final String message =
          data['message']?.toString() ??
          'Unable to send the verification code.';

      if (response.statusCode == 401) {
        _showMessage(
          'Your Google sign-in session is no longer valid. Please sign in again.',
        );
        return;
      }

      if (response.statusCode == 429) {
        _showMessage(
          'Please wait before requesting another verification code.',
        );
        return;
      }

      _showMessage(message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not connect to the verification service. Please check your internet connection.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final String email = _emailController.text.trim().toLowerCase();

    final String code = _otpController.text.trim();

    if (!_hasSentCode) {
      _showMessage('Please send an OTP first.');
      return;
    }

    if (email.isEmpty) {
      _showMessage('Please enter an email address.');
      return;
    }

    if (code.length != 6) {
      _showMessage('Please enter the 6-digit verification code.');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('Please enter numbers only.');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final String? idToken = await _getFirebaseIdToken();

      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          _showMessage(
            'Your Google sign-in session has expired. Please sign in again.',
          );
        }
        return;
      }

      final response = await http.post(
        Uri.parse('$_backendUrl/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'email': email, 'otp': code}),
      );

      Map<String, dynamic> data = {};

      try {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = {};
      }

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200 && data['verified'] == true) {
        await _openBiometricStep();
        return;
      }

      final String message =
          data['message']?.toString() ??
          'The verification code is incorrect or has expired.';

      _showMessage(message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not connect to the verification service. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _openBiometricStep() async {
    if (kIsWeb) {
      _openLanguageScreen();
      return;
    }

    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;

      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        if (mounted) {
          _showMessage(
            'Biometric verification is not available on this device.',
          );
        }
        return;
      }

      final bool authenticated = await _localAuth.authenticate(
        localizedReason:
            'Please verify your identity to continue to Autisolve.',
        biometricOnly: true,
      );

      if (!mounted) {
        return;
      }

      if (authenticated) {
        _openLanguageScreen();
      } else {
        _showMessage('Biometric verification was not completed.');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Biometric verification is unavailable on this device.');
    }
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0 || _isSending || _isVerifying) {
      return;
    }

    await _sendOtp();
  }

  void _openLanguageScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) {
          return LanguageSelectScreen(
            initialCode: 'en',
            onContinue: (String languageCode) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) {
                    return ReportUploadScreen(languageCode: languageCode);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool canEditEmail = !_isSending && !_isVerifying;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _isSending || _isVerifying
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: AppColors.sageLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      size: 40,
                      color: AppColors.sageDark,
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Verify your email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Enter the email address where you want to receive your verification code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.inkSoft,
                    ),
                  ),

                  const SizedBox(height: 22),

                  TextField(
                    controller: _emailController,
                    enabled: canEditEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      hintText: 'you@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.white,
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

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSending || _isVerifying ? null : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Send OTP',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  TextField(
                    controller: _otpController,
                    enabled: _hasSentCode && !_isVerifying && !_isSending,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      color: AppColors.ink,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      labelText: 'Verification code',
                      hintStyle: const TextStyle(
                        fontSize: 25,
                        letterSpacing: 8,
                        color: AppColors.inkFaint,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
                    onSubmitted: (_) {
                      if (_hasSentCode && !_isVerifying && !_isSending) {
                        _verifyCode();
                      }
                    },
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: !_hasSentCode || _isVerifying || _isSending
                          ? null
                          : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify email',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (_hasSentCode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Didn't receive the code?",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed:
                              _secondsRemaining == 0 &&
                                  !_isSending &&
                                  !_isVerifying
                              ? _resendCode
                              : null,
                          child: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _secondsRemaining == 0
                                      ? 'Resend'
                                      : 'Resend in '
                                            '$_secondsRemaining s',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.sageDark,
                                  ),
                                ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 18),

                  const Text(
                    'Never share your verification code with anyone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
