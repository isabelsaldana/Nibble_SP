// lib/signup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInput.finishAutofillContext
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ NEW

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePw = true;
  bool _obscureCf = true;
  bool _submitting = false;

  // --- password strength (0..4) ---
  int _strength = 0;
  int _calcStrength(String s) {
    int score = 0;
    if (s.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(s)) score++;
    if (RegExp(r'[0-9]').hasMatch(s)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(s)) score++;
    return score;
  }

  String get _strengthLabel =>
      ['Very weak', 'Weak', 'Okay', 'Good', 'Strong'][_strength];

  Color get _strengthColor {
    switch (_strength) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value);
    return ok ? null : 'Enter a valid email';
  }

  String? _passwordValidator(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    final problems = <String>[];
    if (value.length < 8) problems.add('8+ chars');
    if (!RegExp(r'[A-Z]').hasMatch(value)) problems.add('1 uppercase');
    if (!RegExp(r'[0-9]').hasMatch(value)) problems.add('1 number');
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(value)) {
      problems.add('1 symbol');
    }
    if (problems.isEmpty) return null;
    return 'Add: ${problems.join(', ')}';
  }

  String? _confirmValidator(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Please confirm your password';
    if (value != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  bool get _isFormValid =>
      _emailValidator(_emailCtrl.text) == null &&
      _passwordValidator(_passwordCtrl.text) == null &&
      _confirmValidator(_confirmCtrl.text) == null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      // 1) Create auth user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2) Seed minimal Firestore user doc so AuthGate knows onboarding is needed once
      final uid = cred.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'onboardingComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) Close autofill context (safe on web too)
      TextInput.finishAutofillContext(shouldSave: true);

      if (!mounted) return;

      // 4) Send them to onboarding (one-time flow)
      Navigator.of(context).pushReplacementNamed('/onboarding');

    } on FirebaseAuthException catch (e) {
      String msg = 'Sign up failed';
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'That email is already in use.';
          break;
        case 'invalid-email':
          msg = 'That email is not valid.';
          break;
        case 'weak-password':
          msg = 'Password is too weak (follow the hints).';
          break;
        case 'operation-not-allowed':
          msg = 'Email/password sign-in is disabled in Firebase.';
          break;
        default:
          msg = e.message ?? msg;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 1,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create your Nibble account',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: _emailValidator,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePw,
                        textInputAction: TextInputAction.next,
                        onChanged: (v) =>
                            setState(() => _strength = _calcStrength(v)),
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscurePw = !_obscurePw),
                            icon: Icon(_obscurePw
                                ? Icons.visibility
                                : Icons.visibility_off),
                            tooltip: _obscurePw ? 'Show' : 'Hide',
                          ),
                        ),
                        validator: _passwordValidator,
                      ),
                      const SizedBox(height: 6),

                      Text(
                        'Strength: $_strengthLabel',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, color: _strengthColor),
                      ),
                      const SizedBox(height: 6),

                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscureCf,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onFieldSubmitted: (_) => _submit(),
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscureCf = !_obscureCf),
                            icon: Icon(_obscureCf
                                ? Icons.visibility
                                : Icons.visibility_off),
                            tooltip: _obscureCf ? 'Show' : 'Hide',
                          ),
                        ),
                        validator: _confirmValidator,
                      ),
                      const SizedBox(height: 16),

                      FilledButton(
                        onPressed: (!_submitting && _isFormValid) ? _submit : null,
                        child: _submitting
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Text('Create account'),
                      ),
                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pushReplacementNamed('/login'),
                        child: const Text("Already have an account? Log in"),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'We use Firebase Auth. Passwords should include 8+ chars, 1 uppercase, 1 number, 1 symbol.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
