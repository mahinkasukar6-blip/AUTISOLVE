import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_colors.dart';
import 'email_otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;

  Future<void> _loginWithGoogle() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? email;

      if (kIsWeb) {
        final GoogleAuthProvider provider = GoogleAuthProvider();

        final UserCredential credential = await _auth.signInWithPopup(provider);

        email = credential.user?.email;
      } else {
        final GoogleSignInAccount googleUser = await GoogleSignIn.instance
            .authenticate();

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final String? idToken = googleAuth.idToken;

        if (idToken == null) {
          throw Exception('Google sign-in did not return an ID token.');
        }

        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );

        email = userCredential.user?.email;
      }

      if (!mounted) {
        return;
      }

      if (email == null || email.trim().isEmpty) {
        _showMessage('We could not retrieve your Google email address.');
        return;
      }

      _openOtpScreen(email.trim());
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(e.message ?? 'Google sign-in failed.');
    } on GoogleSignInException catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(e.description ?? 'Google sign-in was cancelled or failed.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openOtpScreen(String email) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => EmailOtpScreen(email: email)),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: const BoxDecoration(
                      color: AppColors.sageLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 36,
                      color: AppColors.sageDark,
                    ),
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    'Welcome to Autisolve',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Sign in securely to continue caring '
                    'for your family.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.inkSoft,
                    ),
                  ),

                  const SizedBox(height: 42),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loginWithGoogle,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.account_circle_outlined, size: 22),
                      label: Text(
                        _isLoading ? 'Signing in...' : 'Continue with Google',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'After Google sign-in, we will send a '
                    'verification code to your Google email.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.inkFaint,
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: AppColors.inkFaint,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Secure sign-in with Firebase',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
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
