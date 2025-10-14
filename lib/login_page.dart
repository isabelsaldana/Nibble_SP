import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for TextInput.finishAutofillContext
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Form + state
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  String? errorMessage;
  bool _obscurePw = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value);
    return ok ? null : 'Enter a valid email';
  }

  String? _passwordValidator(String? v) {
    if ((v ?? '').isEmpty) return 'Password is required';
    return null;
  }

  // Handles Firebase login logic
  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Nudge Android/iOS to save creds (harmless on web)
      TextInput.finishAutofillContext(shouldSave: true);

      if (!mounted) return;
      // Use named route to stay consistent with main.dart routes
      Navigator.pushReplacementNamed(context, '/home');
      // If you prefer your original navigation:
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
          msg = 'Incorrect email or password.';
          break;
        case 'user-not-found':
          msg = 'No account with that email.';
          break;
        case 'invalid-email':
          msg = 'That email is not valid.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Try again later.';
          break;
        default:
          msg = e.message ?? msg;
      }
      setState(() {
        errorMessage = msg;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitBtnChild = isLoading
        ? const SizedBox(
            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Text('Login', style: TextStyle(color: Colors.white));

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Welcome to Nibble 👩🏻‍🍳',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 40),

                    // Email
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: passwordController,
                      obscureText: _obscurePw,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => loginUser(),
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePw = !_obscurePw),
                          icon: Icon(_obscurePw ? Icons.visibility : Icons.visibility_off),
                          tooltip: _obscurePw ? 'Show' : 'Hide',
                        ),
                      ),
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: 24),

                    // Error
                    if (errorMessage != null)
                      Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                    if (errorMessage != null) const SizedBox(height: 16),

                    // Login Button
                    ElevatedButton(
                      onPressed: isLoading ? null : loginUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: submitBtnChild,
                    ),

                    const SizedBox(height: 16),

                    // Go to Sign Up
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SignUpPage()),
                              );
                            },
                      child: const Text("Don't have an account? Sign up"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
