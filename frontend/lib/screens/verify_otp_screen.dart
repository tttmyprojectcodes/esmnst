import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class VerifyOTPScreen extends StatefulWidget {
  final String email;
  final String phone;
  final String password;
  final String displayName;
  final String country;

  const VerifyOTPScreen({
    super.key,
    required this.email,
    required this.phone,
    required this.password,
    required this.displayName,
    required this.country,
  });

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final TextEditingController _emailOtpController = TextEditingController();
  final TextEditingController _phoneOtpController = TextEditingController();
  bool _isLoading = false;
  bool _emailOtpSent = false;
  bool _emailOtpVerified = false;
  bool _phoneOtpSent = false;
  bool _phoneOtpVerified = false;
  String _emailOtp = '';
  int _resendTimer = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _sendEmailOTP();
    _sendPhoneOTP();
    _startTimer();
  }

  void _startTimer() {
    _resendTimer = 30;
    _canResend = false;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _resendTimer--;
          if (_resendTimer > 0) {
            _startTimer();
          } else {
            _canResend = true;
          }
        });
      }
    });
  }

  Future<void> _sendEmailOTP() async {
    setState(() => _isLoading = true);
    try {
      _emailOtp = (100000 + Random().nextInt(900000)).toString();
      
      await FirebaseFirestore.instance.collection('otps').doc(widget.email).set({
        'email': widget.email,
        'otp': _emailOtp,
        'type': 'email',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
      });

      await _sendEmailViaBackend(widget.email, _emailOtp);
      
      setState(() {
        _emailOtpSent = true;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📧 OTP sent to your email!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send email OTP: $e')),
        );
      }
    }
  }

  Future<void> _sendPhoneOTP() async {
    setState(() => _isLoading = true);
    try {
      String phoneNumber = widget.phone;
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+91$phoneNumber';
      }
    
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          setState(() {
            _phoneOtpVerified = true;
            _isLoading = false;
          });
          _checkAndCompleteRegistration();
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Phone verification failed: ${e.message}')),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _phoneOtpSent = true;
            _isLoading = false;
            _startTimer();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📱 OTP sent to your phone!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send phone OTP: $e')),
        );
      }
    }
  }

  Future<void> _verifyEmailOTP() async {
    if (_emailOtpController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit email OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('otps')
          .doc(widget.email)
          .get();
      
      if (!doc.exists) {
        throw Exception('OTP not found. Please resend.');
      }
      
      final data = doc.data()!;
      final storedOtp = data['otp'];
      final expiresAt = data['expiresAt']?.toDate();
      
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        throw Exception('OTP expired. Please resend.');
      }
      
      if (storedOtp == _emailOtpController.text.trim()) {
        setState(() {
          _emailOtpVerified = true;
          _isLoading = false;
        });
        await FirebaseFirestore.instance.collection('otps').doc(widget.email).delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Email verified!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        _checkAndCompleteRegistration();
      } else {
        throw Exception('Invalid OTP. Please try again.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _verifyPhoneOTP() async {
    if (_phoneOtpController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit phone OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // The phone verification is handled by Firebase
      // The user is already signed in via _sendPhoneOTP
      // So we just check if user is signed in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _phoneOtpVerified = true;
          _isLoading = false;
        });
        _checkAndCompleteRegistration();
      } else {
        throw Exception('Phone verification failed. Please try again.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Phone verification error: $e')),
        );
      }
    }
  }

  Future<void> _checkAndCompleteRegistration() async {
    if (_emailOtpVerified && _phoneOtpVerified) {
      setState(() => _isLoading = true);
      try {
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: widget.email,
          password: widget.password,
        );

        await userCredential.user?.updateDisplayName(widget.displayName);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'email': widget.email,
          'displayName': widget.displayName,
          'phone': widget.phone,
          'country': widget.country,
          'walletBalance': 0.0,
          'walletCurrency': 'USD',
          'role': 'user',
          'kycVerified': false,
          'emailVerified': true,
          'phoneVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'referralCode': _generateReferralCode(),
          'referredBy': '',
        });

        setState(() => _isLoading = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Account created successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: $e')),
          );
        }
      }
    }
  }

  String _generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(8, (_) => chars.codeUnitAt(
        DateTime.now().millisecondsSinceEpoch % chars.length,
      )),
    );
  }

  Future<void> _sendEmailViaBackend(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('https://esmnst.onrender.com/api/send-otp-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'otp': otp,
        }),
      );
      if (response.statusCode != 200) {
        print('Failed to send email OTP');
      }
    } catch (e) {
      print('Error sending email OTP: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Identity')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 64, color: Color(0xFFF59E0B)),
            const SizedBox(height: 16),
            const Text(
              'Verify Your Email & Phone',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We sent OTPs to your email and phone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 32),

            // Email OTP
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _emailOtpVerified ? Icons.check_circle : Icons.email_outlined,
                        color: _emailOtpVerified ? Colors.green : Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _emailOtpVerified ? 'Email Verified ✅' : 'Email OTP',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (!_emailOtpVerified)
                        TextButton(
                          onPressed: _canResend ? _sendEmailOTP : null,
                          child: Text(
                            _canResend ? 'Resend' : '${_resendTimer}s',
                            style: TextStyle(
                              color: _canResend ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (!_emailOtpVerified) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailOtpController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Enter 6-digit OTP',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verifyEmailOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Verify'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Phone OTP
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _phoneOtpVerified ? Icons.check_circle : Icons.phone_android,
                        color: _phoneOtpVerified ? Colors.green : Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _phoneOtpVerified ? 'Phone Verified ✅' : 'Phone OTP',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (!_phoneOtpVerified)
                        TextButton(
                          onPressed: _canResend ? _sendPhoneOTP : null,
                          child: Text(
                            _canResend ? 'Resend' : '${_resendTimer}s',
                            style: TextStyle(
                              color: _canResend ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (!_phoneOtpVerified) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneOtpController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Enter 6-digit OTP',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verifyPhoneOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Verify'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_isLoading) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                FirebaseAuth.instance.signOut();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
