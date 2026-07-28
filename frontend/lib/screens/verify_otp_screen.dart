import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class VerifyOTPScreen extends StatefulWidget {
  final String email;
  final String password;
  final String displayName;
  final String phone;
  final String country;

  const VerifyOTPScreen({
    super.key,
    required this.email,
    required this.password,
    required this.displayName,
    required this.phone,
    required this.country,
  });

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  String _generatedOtp = '';
  int _resendTimer = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _sendOTP();
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

  Future<void> _sendOTP() async {
    setState(() => _isLoading = true);
    try {
      // Generate 6-digit OTP
      _generatedOtp = (100000 + Random().nextInt(900000)).toString();
      
      // Send OTP via your backend
      await _sendEmailOTP(widget.email, _generatedOtp);
      
      // Store OTP in Firestore with expiry
      await FirebaseFirestore.instance.collection('otps').doc(widget.email).set({
        'email': widget.email,
        'otp': _generatedOtp,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
        'verified': false,
      });
      
      setState(() {
        _otpSent = true;
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
          SnackBar(content: Text('Failed to send OTP: $e')),
        );
      }
    }
  }

  Future<void> _sendEmailOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('https://esimnest.onrender.com/api/send-otp-email'),
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

  Future<void> _verifyOTP() async {
    if (_otpController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Check OTP in Firestore
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
      
      // Check expiry
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        throw Exception('OTP expired. Please resend.');
      }
      
      // Check OTP match
      if (storedOtp == _otpController.text.trim()) {
        // ✅ OTP Verified - Create Account
        await _createAccount();
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

  Future<void> _createAccount() async {
    try {
      // Create Firebase Auth account
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(widget.displayName);

      // Create user document in Firestore
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
        'emailVerified': true,  // ✅ Mark as verified
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'referralCode': _generateReferralCode(),
        'referredBy': '',
      });

      // Delete OTP from Firestore
      await FirebaseFirestore.instance.collection('otps').doc(widget.email).delete();

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

  String _generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(8, (_) => chars.codeUnitAt(
        DateTime.now().millisecondsSinceEpoch % chars.length,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF1E3A5F)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email_outlined, size: 64, color: Color(0xFFF59E0B)),
                const SizedBox(height: 16),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit OTP to: ${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
                const SizedBox(height: 32),
                
                if (!_otpSent) ...[
                  const CircularProgressIndicator(color: Color(0xFFF59E0B)),
                  const SizedBox(height: 16),
                  const Text('Sending OTP...', style: TextStyle(color: Color(0xFF94A3B8))),
                ] else ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: _otpController,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: InputDecoration(
                            labelText: 'Enter 6-digit OTP',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _canResend ? _sendOTP : null,
                              child: Text(
                                _canResend ? 'Resend OTP' : 'Resend in ${_resendTimer}s',
                                style: TextStyle(
                                  color: _canResend ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: const Color(0xFF0A1628),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0A1628),
                                      ),
                                    )
                                  : const Text(
                                      'Verify',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    FirebaseAuth.instance.signOut();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
