import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../theme/app_colors.dart';
import 'email_otp_screen.dart';

class BiometricScreen extends StatefulWidget {
  final String email;

  const BiometricScreen({super.key, required this.email});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _isLoading = false;

  Future<void> _verifyBiometric() async {
    if (kIsWeb) {
      _openOtpScreen();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;

      final bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        _showMessage(
          'Biometric authentication is not available on this device.',
        );
        return;
      }

      final bool authenticated = await _auth.authenticate(
        localizedReason: 'Verify your identity to continue to Autisolve.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!mounted) return;

      if (authenticated) {
        _openOtpScreen();
      } else {
        _showMessage('Biometric verification was not completed.');
      }
    } on LocalAuthException catch (e) {
      if (!mounted) return;

      _showMessage(_biometricErrorMessage(e));
    } catch (e) {
      if (!mounted) return;

      _showMessage('Biometric verification failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openOtpScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => EmailOtpScreen(email: widget.email)),
    );
  }

  String _biometricErrorMessage(LocalAuthException error) {
    switch (error.code) {
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'This device does not have biometric hardware.';

      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'No fingerprint or face is enrolled on this device.';

      case LocalAuthExceptionCode.biometricLockout:
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Biometric authentication is temporarily locked.';

      case LocalAuthExceptionCode.userCanceled:
        return 'Biometric verification was cancelled.';

      case LocalAuthExceptionCode.systemCanceled:
        return 'Biometric verification was cancelled by the system.';

      default:
        return 'Biometric verification could not be completed.';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = kIsWeb;

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
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: AppColors.sageLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      size: 48,
                      color: AppColors.sageDark,
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Verify your identity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    isWeb
                        ? 'Biometric verification is handled differently on the web.'
                        : 'Use your face or fingerprint to securely continue.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.inkSoft,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 20,
                          color: AppColors.inkFaint,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _verifyBiometric,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.fingerprint, size: 23),
                      label: Text(
                        isWeb
                            ? 'Continue to email verification'
                            : 'Verify with biometrics',
                        textAlign: TextAlign.center,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (!isWeb)
                    const Text(
                      'Your biometric data stays on your device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkFaint,
                      ),
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
