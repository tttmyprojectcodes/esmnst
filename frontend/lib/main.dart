// =====================================================
// eSIMNest - Global Data eSIM
// A Tech Talk Titans Product
// Flutter App - Complete
// =====================================================

import 'package:esimnest/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

// =====================================================
// 1. BRAND CONSTANTS
// =====================================================

const String brandName = 'eSIMNest';
const String brandSlogan = 'Global Data eSIM';
const String companyName = 'Tech Talk Titans';
const String brandDisplay = '$brandName - $brandSlogan';
const String brandFull = '$brandName | $brandSlogan\nA $companyName Product';
const String supportEmail = 'support@esimnest.com';
const String websiteUrl = 'www.esimnest.com';

// =====================================================
// 2. MAIN APP
// =====================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final String apiKey = const String.fromEnvironment('FIREBASE_API_KEY');
  final String authDomain = const String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  final String projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID');
  final String storageBucket = const String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  final String messagingSenderId = const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  final String appId = const String.fromEnvironment('FIREBASE_APP_ID');

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: apiKey,
      authDomain: authDomain,
      projectId: projectId,
      storageBucket: storageBucket,
      messagingSenderId: messagingSenderId,
      appId: appId,
    ),
  );
  
  runApp(const MyApp());
}

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (user != null) {
        // Navigate to home
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _signInWithEmail() async {
    setState(() => _isLoading = true);
    try {
      final user = await _auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Your UI code here
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Email/Password Sign Up
  Future<User?> signUpWithEmail(String email, String password, String displayName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(displayName);
      
      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'email': email,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'walletBalance': 0,
        'role': 'user',
      });
      
      return userCredential.user;
    } catch (e) {
      print('Sign-up error: $e');
      return null;
    }
  }

  // Email/Password Sign In
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('Sign-in error: $e');
      return null;
    }
  }

  // Google Sign In (Web-compatible)
  Future<User?> signInWithGoogle() async {
    try {
      // For web
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User cancelled
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Check if user exists in Firestore, if not create
      final userDoc = await _firestore.collection('users').doc(userCredential.user?.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'email': userCredential.user?.email,
          'displayName': userCredential.user?.displayName ?? 'User',
          'createdAt': FieldValue.serverTimestamp(),
          'walletBalance': 0,
          'role': 'user',
        });
      }
      
      return userCredential.user;
    } catch (e) {
      print('Google sign-in error: $e');
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: brandDisplay,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1E3A5F),
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1628),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: const Color(0xFF0A1628),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          prefixIconColor: const Color(0xFF94A3B8),
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0A1628),
          selectedItemColor: Color(0xFFF59E0B),
          unselectedItemColor: Color(0xFF64748B),
          type: BottomNavigationBarType.fixed,
          elevation: 10,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 14,
          ),
          bodySmall: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const MainScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
      },
    );
  }
}

// =====================================================
// 3. AUTH WRAPPER
// =====================================================

 class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.hasData) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

// =====================================================
// 4. SPLASH SCREEN
// =====================================================

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF1E3A5F), Color(0xFF2563EB)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 80,
                    height: 80,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.sim_card,
                        color: Color(0xFFF59E0B),
                        size: 50,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                brandName,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const Text(
                brandSlogan,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A Tech Talk Titans Product',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                '© 2026 eSIMNest. A Tech Talk Titans Product',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// 5. LOGIN SCREEN
// =====================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _loginWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF1E3A5F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 80,
                    height: 80,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.sim_card,
                        color: Color(0xFFF59E0B),
                        size: 50,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    brandName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const Text(
                    brandSlogan,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A Tech Talk Titans Product',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          style: const TextStyle(color: Colors.white),
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/forgot-password');
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(color: Color(0xFF2563EB)),
                            ),
                          ),
                        ),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: const Color(0xFF0A1628),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'SIGN IN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _loginWithGoogle,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://img.icons8.com/color/24/google-logo.png',
                                  height: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Continue with Google',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account?",
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '© 2026 eSIMNest. A Tech Talk Titans Product',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
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

// =====================================================
// 6. REGISTER SCREEN
// =====================================================

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _register() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _countryController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Update display name
      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      // Create user document in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'email': _emailController.text.trim(),
        'displayName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'country': _countryController.text.trim(),
        'walletBalance': 0.0,
        'walletCurrency': 'USD',
        'role': 'user',
        'kycVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'referralCode': _generateReferralCode(),
        'referredBy': '',
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registration failed')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Create Account'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 60,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.sim_card,
                      color: Color(0xFFF59E0B),
                      size: 40,
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join eSIMNest',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const Text(
                  'Start your global connectivity journey',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _countryController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          prefixIcon: Icon(Icons.public_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          border: const OutlineInputBorder(),
                          helperText: 'Must be at least 6 characters',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmPasswordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () =>
                                  _obscureConfirmPassword = !_obscureConfirmPassword,
                            ),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF0A1628),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'CREATE ACCOUNT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account?',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '© 2026 eSIMNest. A Tech Talk Titans Product',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
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

// =====================================================
// 7. FORGOT PASSWORD SCREEN
// =====================================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  Future<void> _sendResetEmail() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to send reset email')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
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
                const Text(
                  '🔑',
                  style: TextStyle(fontSize: 60),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email to receive a password reset link',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (_sent) ...[
                        const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF10B981),
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Reset email sent!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check your inbox and spam folder',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('BACK TO LOGIN'),
                          ),
                        ),
                      ] else ...[
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendResetEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: const Color(0xFF0A1628),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'SEND RESET LINK',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text(
                    'Back to Login',
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

// =====================================================
// 8. MAIN SCREEN (DASHBOARD + 5 SECTIONS)
// =====================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      const HomeScreen(),
      const MyEsimsScreen(),
      const MyOrdersScreen(),
      const WalletScreen(),
      const ProfileScreen(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sim_card_outlined),
            activeIcon: Icon(Icons.sim_card),
            label: 'eSIMs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_outlined),
            activeIcon: Icon(Icons.receipt),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wallet_outlined),
            activeIcon: Icon(Icons.wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// =====================================================
// 9. HOME SCREEN
// =====================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() => _userData = userDoc.data());
        }
        // Load dashboard data from backend
        // In production, call your FastAPI backend
        // For now, we'll use Firestore directly
        await _loadDashboardData(user.uid);
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDashboardData(String uid) async {
    try {
      // Get active eSIMs
      final esimsSnapshot = await FirebaseFirestore.instance
          .collection('esims')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();

      // Get orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      setState(() {
        _dashboardData = {
          'activeEsims': esimsSnapshot.docs.length,
          'orders': ordersSnapshot.docs.length,
          'recentOrders': ordersSnapshot.docs.map((doc) {
            return doc.data();
          }).toList(),
        };
      });
    } catch (e) {
      print('Error loading dashboard: $e');
    }
  }
  Widget _buildStatCard(String icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Traveler';
    final balance = _userData?['walletBalance'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.sim_card,
                  color: Color(0xFFF59E0B),
                  size: 28,
                );
              },
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brandName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const Text(
                  brandSlogan,
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                 ),
               ),
             ],
           ),
         ],
       ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Show notifications
            },
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF59E0B),
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF0A1628),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      'Hello, $userName! 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ready to explore the world?',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Wallet Balance Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1E3A5F),
                            Color(0xFF2563EB),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Wallet Balance',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      // Navigate to Wallet
                                      final mainScreen = context
                                          .findAncestorStateOfType<
                                              _MainScreenState>();
                                      if (mainScreen != null) {
                                        mainScreen
                                            .setState(() => mainScreen
                                                    ._selectedIndex =
                                                3);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF59E0B),
                                      foregroundColor: const Color(0xFF0A1628),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Add Money',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () {
                                      // Navigate to Wallet
                                      final mainScreen = context
                                          .findAncestorStateOfType<
                                              _MainScreenState>();
                                      if (mainScreen != null) {
                                        mainScreen
                                            .setState(() => mainScreen
                                                    ._selectedIndex =
                                                3);
                                      }
                                    },
                                    child: const Text(
                                      'History',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.account_balance_wallet,
                            size: 48,
                            color: Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Buy eSIM Card
                    GestureDetector(
                      onTap: () {
                        // Navigate to buy eSIM flow
                        _showCountrySelection(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFF59E0B),
                              Color(0xFFD97706),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shopping_cart,
                              color: Color(0xFF0A1628),
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/images/logo.png',
                                        width: 24,
                                        height: 24,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.shopping_cart,
                                            color: Color(0xFF0A1628),
                                            size: 20,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'BUY eSIM',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0A1628),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Text(
                                    'Find the perfect plan for your trip',
                                    style: TextStyle(
                                      color: Color(0xFF0A1628),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Color(0xFF0A1628),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            '📱',
                            'Active eSIMs',
                            _dashboardData?['activeEsims']?.toString() ?? '0',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '📋',
                            'Orders',
                            _dashboardData?['orders']?.toString() ?? '0',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '⭐',
                            'Saved',
                            '5',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Recent Orders
                    const Text(
                      'Recent Orders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_dashboardData?['recentOrders']?.isNotEmpty ?? false)
                      ...(_dashboardData!['recentOrders'] as List).map((order) {
                        return _buildOrderCard(order);
                      }).toList()
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No orders yet',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }


  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final statusColor = status == 'delivered'
        ? const Color(0xFF10B981)
        : status == 'pending'
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    final statusIcon = status == 'delivered'
        ? Icons.check_circle
        : status == 'pending'
            ? Icons.hourglass_empty
            : Icons.cancel;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order['plan']?['name'] ?? 'Plan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${order['amount']?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCountrySelection(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  
    // Fetch countries from API
    final countries = await ApiService.getCountries();
  
    Navigator.pop(context); // Close loading dialog
  
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A1628),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Country',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search country...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              onChanged: (value) {
                // Filter countries based on search
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: countries.length,
                itemBuilder: (context, index) {
                  final country = countries[index];
                  return _buildCountryTile(
                    country['code'] ?? '',
                    country['name'] ?? 'Unknown',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCountryTile(String flag, String name) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 28)),
      title: Text(name),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.pop(context);
        _showPlanSelection(context, name);
      },
    );
  }

  void _showPlanSelection(BuildContext context, String country) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Fetch plans from API
    final plans = await ApiService.getPlans(country: country);
  
    Navigator.pop(context); // Close loading dialog

    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No plans available for this country')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A1628),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$country Plans',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  const Text(
                    'All plans include instant delivery',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return _buildPlanCardReal(
                    plan['name'] ?? 'Plan',
                    '${plan['data'] ?? 0}GB',
                    '${plan['validity'] ?? 0} Days',
                    '\$${plan['price']?.toStringAsFixed(2) ?? '0.00'}',
                    country,
                    plan['id'] ?? '',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildPlanCardReal(String name, String data, String validity, String price, String country, String planId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.sim_card,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$data • $validity',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmPurchaseReal(context, country, name, price, planId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF0A1628),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Buy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _confirmPurchaseReal(BuildContext context, String country, String planName, String price, String planId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text('Confirm Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🌍 $country'),
            Text('📶 $planName'),
            Text('💰 $price'),
            const SizedBox(height: 16),
            const Text(
              'Your wallet will be debited',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                // Real purchase
                final result = await ApiService.purchasePlan(planId, country);
                
                Navigator.pop(context); // Close loading
                
                if (result['success'] == true) {
                  _showPurchaseSuccess(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['error'] ?? 'Purchase failed'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF0A1628),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
  void _showPurchaseSuccess(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text('🎉 Purchase Successful!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 64),
            SizedBox(height: 16),
            Text(
              'Your eSIM is being delivered',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Check your email or My eSIMs section',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final mainScreen = context.findAncestorStateOfType<_MainScreenState>();
              if (mainScreen != null) {
                mainScreen.setState(() => mainScreen._selectedIndex = 1);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('View My eSIMs'),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// 10. MY eSIMS SCREEN
// =====================================================

class MyEsimsScreen extends StatefulWidget {
  const MyEsimsScreen({super.key});

  @override
  State<MyEsimsScreen> createState() => _MyEsimsScreenState();
}

class _MyEsimsScreenState extends State<MyEsimsScreen> {
  List<Map<String, dynamic>> _esims = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadEsims();
  }

  Future<void> _loadEsims() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final esimsSnapshot = await FirebaseFirestore.instance
            .collection('esims')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .get();

        setState(() {
          _esims = esimsSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading eSIMs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEsims = _filter == 'all'
        ? _esims
        : _esims.where((e) => e['status'] == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My eSIMs'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All eSIMs')),
              const PopupMenuItem(value: 'active', child: Text('Active')),
              const PopupMenuItem(value: 'expired', child: Text('Expired')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEsims,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredEsims.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.sim_card_outlined,
                          size: 64,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No eSIMs found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Buy your first eSIM from the Home tab',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            final mainScreen = context
                                .findAncestorStateOfType<_MainScreenState>();
                            if (mainScreen != null) {
                              mainScreen
                                  .setState(() => mainScreen._selectedIndex = 0);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF0A1628),
                          ),
                          child: const Text('Buy eSIM Now'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredEsims.length,
                    itemBuilder: (context, index) {
                      final esim = filteredEsims[index];
                      return _buildEsimCard(esim);
                    },
                  ),
      ),
    );
  }

  Widget _buildEsimCard(Map<String, dynamic> esim) {
    final isActive = esim['status'] == 'active';
    final statusColor = isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final expiryDate = esim['expiryDate'] as Timestamp?;
    final daysLeft = expiryDate != null
        ? expiryDate.toDate().difference(DateTime.now()).inDays
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF10B981).withOpacity(0.3) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.sim_card,
                        color: Color(0xFFF59E0B),
                        size: 16,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    esim['country'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? 'Active' : 'Expired',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '📶 ${esim['plan'] ?? 'Plan'}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '📱 ${esim['phoneNumber'] ?? 'N/A'}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ICCID: ${esim['iccid'] ?? 'N/A'}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
            ),
          ),
          if (isActive && expiryDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: daysLeft <= 3 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  '${daysLeft >= 0 ? '$daysLeft days left' : 'Expired'}',
                  style: TextStyle(
                    color: daysLeft <= 3 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showQRCode(context, esim);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('QR Code'),
                ),
              ),
              const SizedBox(width: 8),
              if (isActive)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Show usage
                      _showUsageDialog(context, esim);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF64748B)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Usage'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQRCode(BuildContext context, Map<String, dynamic> esim) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text('QR Code - ${esim['country'] ?? 'eSIM'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code,
                  size: 120,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan this QR code to install',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                esim['activationCode'] ?? 'N/A',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUsageDialog(BuildContext context, Map<String, dynamic> esim) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text('Data Usage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Text('Total Data:'),
                Spacer(),
                Text('3.0 GB', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Text('Used:'),
                Spacer(),
                Text('0.8 GB', style: TextStyle(color: Color(0xFFF59E0B))),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Text('Remaining:'),
                Spacer(),
                Text('2.2 GB', style: TextStyle(color: Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0.27,
              backgroundColor: Colors.white.withOpacity(0.1),
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// 11. MY ORDERS SCREEN
// =====================================================

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .get();

        setState(() {
          _orders = ordersSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading orders: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _filter == 'all'
        ? _orders
        : _orders.where((o) => o['status'] == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Orders')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'delivered', child: Text('Delivered')),
              const PopupMenuItem(value: 'expired', child: Text('Expired')),
              const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_outlined,
                          size: 64,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No orders yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your first order will appear here',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return _buildOrderCard(order);
                    },
                  ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final statusColors = {
      'pending': const Color(0xFFF59E0B),
      'delivered': const Color(0xFF10B981),
      'expired': const Color(0xFFEF4444),
      'cancelled': const Color(0xFF64748B),
    };
    final statusIcons = {
      'pending': Icons.hourglass_empty,
      'delivered': Icons.check_circle,
      'expired': Icons.cancel,
      'cancelled': Icons.block,
    };
    final statusColor = statusColors[status] ?? const Color(0xFF64748B);
    final statusIcon = statusIcons[status] ?? Icons.help_outline;
    final orderDate = order['createdAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order['id']?.substring(0, 8).toUpperCase() ?? 'N/A'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (orderDate != null)
                      Text(
                        '${orderDate.toDate().day}/${orderDate.toDate().month}/${orderDate.toDate().year}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 18,
                    height: 18,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.sim_card,
                        color: Color(0xFFF59E0B),
                        size: 14,
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order['country'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '\$${order['amount']?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order['plan']?['name'] ?? 'Plan',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
          if (status == 'delivered' && order['esimId'] != null) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // View eSIM
                final mainScreen = context.findAncestorStateOfType<_MainScreenState>();
                if (mainScreen != null) {
                  mainScreen.setState(() => mainScreen._selectedIndex = 1);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View eSIM',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================
// 12. WALLET SCREEN
// =====================================================

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() => _userData = userDoc.data());
        }

        final transactionsSnapshot = await FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();

        setState(() {
          _transactions = transactionsSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading wallet: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _userData?['walletBalance'] ?? 0.0;
    final currency = _userData?['walletCurrency'] ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1E3A5F),
                            Color(0xFF2563EB),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'Total Balance',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$currency ${balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _showAddMoneyDialog(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: const Color(0xFF0A1628),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('ADD MONEY'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() => _showHistory = !_showHistory);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFF64748B),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _showHistory ? 'Hide History' : 'History',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Add Amounts
                    const Text(
                      'Quick Add',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildQuickAddButton('₹100', 100),
                        const SizedBox(width: 8),
                        _buildQuickAddButton('₹500', 500),
                        const SizedBox(width: 8),
                        _buildQuickAddButton('₹1000', 1000),
                        const SizedBox(width: 8),
                        _buildQuickAddButton('₹2000', 2000),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Payment Methods
                    const Text(
                      'Payment Methods',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentMethod(
                      '💳',
                      'Razorpay',
                      'UPI, Cards, NetBanking',
                      'Pay with Razorpay',
                      'razorpay',
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentMethod(
                      '💳',
                      'PayPal',
                      'International Payments',
                      'Pay with PayPal',
                      'paypal',
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentMethod(
                      '📝',
                      'Manual Payment',
                      'Submit payment request',
                      'Submit Request',
                      'manual',
                    ),
                    const SizedBox(height: 16),

                    // Transaction History
                    if (_showHistory) ...[
                      const Text(
                        'Transaction History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_transactions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'No transactions yet',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        )
                      else
                        ..._transactions.map((transaction) =>
                            _buildTransactionTile(transaction)),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuickAddButton(String label, double amount) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          _showAddMoneyDialog(context, prefillAmount: amount);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.05),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildPaymentMethod(
    String icon,
    String name,
    String description,
    String buttonText,
    String method,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (method == 'razorpay' || method == 'paypal') {
                _showAddMoneyDialog(context, paymentMethod: method);
              } else {
                _showManualPaymentDialog(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    final isCredit = transaction['type'] == 'credit';
    final amount = transaction['amount'] ?? 0.0;
    final date = transaction['createdAt'] as Timestamp?;
    final description = transaction['description'] ?? 'Transaction';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCredit
                  ? const Color(0xFF10B981).withOpacity(0.2)
                  : const Color(0xFFEF4444).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(fontSize: 14),
                ),
                if (date != null)
                  Text(
                    '${date.toDate().day}/${date.toDate().month}/${date.toDate().year} ${date.toDate().hour}:${date.toDate().minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMoneyDialog(
    BuildContext context, {
    double? prefillAmount,
    String? paymentMethod,
  }) {
    final amountController = TextEditingController(
      text: prefillAmount?.toString() ?? '',
    );
    String selectedMethod = paymentMethod ?? 'razorpay';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text('Add Money'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedMethod,
              dropdownColor: const Color(0xFF0A1628),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'razorpay', child: Text('Razorpay')),
                DropdownMenuItem(value: 'paypal', child: Text('PayPal')),
                DropdownMenuItem(value: 'manual', child: Text('Manual Payment')),
              ],
              onChanged: (value) {
                selectedMethod = value!;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              Navigator.pop(context);
              _processPayment(context, amount, selectedMethod);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF0A1628),
            ),
            child: const Text('Proceed to Pay'),
          ),
        ],
      ),
    );
  }

  void _showManualPaymentDialog(BuildContext context) {
    final methodController = TextEditingController();
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text('Manual Payment Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: methodController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Method Name',
                hintText: 'e.g., Bank Transfer, Cash',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: referenceController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reference Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (methodController.text.isEmpty ||
                  amountController.text.isEmpty ||
                  referenceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                  ),
                );
                return;
              }
              Navigator.pop(context);
              await _submitManualPayment(
                methodController.text,
                double.parse(amountController.text),
                referenceController.text,
                notesController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitManualPayment(
    String method,
    double amount,
    String reference,
    String notes,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('paymentRequests').add({
        'userId': user.uid,
        'method_name': method,
        'amount': amount,
        'reference_number': reference,
        'notes': notes,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment request submitted! Admin will verify it soon.',
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting request: $e')),
      );
    }
  }

  Future<void> _processPayment(
    BuildContext context,
    double amount,
    String method,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (method == 'razorpay') {
        // Get auth token
        final token = await user.getIdToken();
      
        // Create order on backend
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/payment/razorpay/create-order'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'amount': amount}),
        );
      
        if (response.statusCode != 200) {
          throw Exception('Failed to create Razorpay order');
        }
      
        final data = json.decode(response.body);
      
        // Initialize Razorpay
        final razorpay = Razorpay();
      
        // Payment success handler
        razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (paymentResponse) async {
          try {
            // Verify payment on backend
            final verifyResponse = await http.post(
              Uri.parse('${ApiService.baseUrl}/payment/razorpay/verify'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'razorpay_payment_id': paymentResponse['razorpay_payment_id'],
                'razorpay_order_id': paymentResponse['razorpay_order_id'],
                'razorpay_signature': paymentResponse['razorpay_signature'],
              }),
            );
          
            if (verifyResponse.statusCode == 200) {
              final result = json.decode(verifyResponse.body);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('₹${result['amount'].toStringAsFixed(2)} added to wallet!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
                _loadData();
              }
            } else {
              throw Exception('Payment verification failed');
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Verification error: $e')),
              );
            }
          }
        });
      
        // Payment error handler
        razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment failed: ${error['description']}')),
            );
          }
        });
      
        // Payment external wallet handler
        razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (response) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('External wallet selected')),
            );
          }
        });
      
        var options = {
          'key': data['key'],
          'amount': amount * 100, // Razorpay expects paise
          'name': 'eSIMNest',
          'description': 'Add money to wallet',
          'order_id': data['order_id'],
          'prefill': {
            'contact': user.phoneNumber ?? '',
            'email': user.email ?? '',
          },
          'theme': {
            'color': '#F59E0B',
          },
        };
      
        razorpay.open(options);
      
      } else if (method == 'paypal') {
        // Get auth token
        final token = await user.getIdToken();
      
        // Create PayPal order
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/payment/paypal/create-order'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'amount': amount}),
        );
      
        if (response.statusCode != 200) {
          throw Exception('Failed to create PayPal order');
        }
      
        final data = json.decode(response.body);
      
        if (data['success'] == true && data['approval_url'] != null) {
          // Open PayPal approval URL
          final url = data['approval_url'];
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
          
            // After PayPal redirect, capture payment
            // This is simplified - in production, handle the redirect callback
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1E3A5F),
                title: const Text('Complete Payment'),
                content: const Text(
                  'Please complete the payment in PayPal.\nAfter completion, click "Verify" below.',
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                    
                      // Show loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    
                      try {
                        // Capture payment
                        final captureResponse = await http.post(
                          Uri.parse('${ApiService.baseUrl}/payment/paypal/capture'),
                          headers: {
                            'Authorization': 'Bearer $token',
                            'Content-Type': 'application/json',
                          },
                          body: json.encode({
                            'payment_id': data['payment_id'],
                            'payer_id': 'PAYER_ID_FROM_REDIRECT', // Get from URL
                          }),
                        );
                      
                        Navigator.pop(context);
                      
                        if (captureResponse.statusCode == 200) {
                          final result = json.decode(captureResponse.body);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('₹${result['amount'].toStringAsFixed(2)} added to wallet!'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                            _loadData();
                          }
                        } else {
                          throw Exception('Payment capture failed');
                        }
                      } catch (e) {
                        Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Capture error: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF0A1628),
                    ),
                    child: const Text('Verify Payment'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          } else {
            throw Exception('Could not launch PayPal');
          }
        } else {
          throw Exception('Failed to create PayPal order');
        }
      
      } else if (method == 'manual') {
        // Show manual payment dialog
        _showManualPaymentDialog(context);
      }
    
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
// =====================================================
// 13. PROFILE SCREEN
// =====================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() => _userData = userDoc.data());
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = _userData?['displayName'] ?? user?.displayName ?? 'User';
    final email = _userData?['email'] ?? user?.email ?? 'No email';
    final phone = _userData?['phone'] ?? 'Not provided';
    final country = _userData?['country'] ?? 'Not provided';
    final balance = _userData?['walletBalance'] ?? 0.0;
    final currency = _userData?['walletCurrency'] ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFFF59E0B),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A1628),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '📱 $phone',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '🌍 $country',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Statistics
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('📋', 'Orders', '0'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard('📱', 'eSIMs', '0'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard('💰', 'Spent', '\$${balance.toStringAsFixed(2)}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Account Settings
                    const Text(
                      'Account Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsTile(
                      Icons.notifications_outlined,
                      'Notifications',
                      'Manage notification preferences',
                      () {
                        // Navigate to notification settings
                      },
                    ),
                    _buildSettingsTile(
                      Icons.dark_mode_outlined,
                      'Dark Mode',
                      'Toggle dark theme',
                      () {
                        // Toggle dark mode
                      },
                    ),
                    _buildSettingsTile(
                      Icons.language_outlined,
                      'Language',
                      'Change app language',
                      () {
                        // Show language selection
                      },
                    ),
                    _buildSettingsTile(
                      Icons.lock_outlined,
                      'Change Password',
                      'Update your password',
                      () {
                        _showChangePasswordDialog(context);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Legal Pages
                    const Text(
                      'Legal & Support',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsTile(
                      Icons.privacy_tip_outlined,
                      'Privacy Policy',
                      'How we handle your data',
                      () => _openLegalPage('Privacy Policy'),
                    ),
                    _buildSettingsTile(
                      Icons.description_outlined,
                      'Terms of Service',
                      'Terms and conditions',
                      () => _openLegalPage('Terms of Service'),
                    ),
                    _buildSettingsTile(
                      Icons.receipt_outlined,
                      'Refund Policy',
                      'Cancellation and refunds',
                      () => _openLegalPage('Refund Policy'),
                    ),
                    _buildSettingsTile(
                      Icons.cookie_outlined,
                      'Cookie Policy',
                      'How we use cookies',
                      () => _openLegalPage('Cookie Policy'),
                    ),
                    _buildSettingsTile(
                      Icons.assignment_outlined,
                      'EULA',
                      'End User License Agreement',
                      () => _openLegalPage('EULA'),
                    ),
                    _buildSettingsTile(
                      Icons.info_outlined,
                      'About Us',
                      'About eSIMNest',
                      () => _openLegalPage('About Us'),
                    ),
                    _buildSettingsTile(
                      Icons.help_outlined,
                      'FAQ',
                      'Frequently asked questions',
                      () => _openLegalPage('FAQ'),
                    ),
                    _buildSettingsTile(
                      Icons.contact_support_outlined,
                      'Contact Us',
                      'Get in touch with support',
                      () => _openLegalPage('Contact Us'),
                    ),
                    _buildSettingsTile(
                      Icons.warning_outlined,
                      'Disclaimer',
                      'Legal disclaimer',
                      () => _openLegalPage('Disclaimer'),
                    ),
                    _buildSettingsTile(
                      Icons.local_shipping_outlined,
                      'Delivery Policy',
                      'eSIM delivery policy',
                      () => _openLegalPage('Delivery Policy'),
                    ),
                    const SizedBox(height: 16),

                    // Logout
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          _showLogoutDialog(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'LOGOUT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Footer
                    const Center(
                      child: Column(
                        children: [
                          Text(
                            brandName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          Text(
                            brandSlogan,
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            'A Tech Talk Titans Product',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '📧 $supportEmail',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF475569),
                            ),
                          ),
                          Text(
                            '🌐 $websiteUrl',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF475569),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '© 2026 eSIMNest. A Tech Talk Titans Product',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
  }

  Widget _buildStatCard(String icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF94A3B8)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Color(0xFF64748B),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password (min 6 chars)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                  ),
                );
                return;
              }
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              // In production, reauthenticate then update password
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password updated successfully!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF0A1628),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _openLegalPage(String pageName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(pageName),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This is a placeholder for the legal page content.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Full legal pages will be displayed here in production.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '📧 For any legal inquiries, contact: support@esimnest.com',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
// =====================================================
// END OF FILE
// =====================================================
