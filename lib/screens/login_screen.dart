import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await _authService.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
        );
      } else {
        await _authService.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Something went wrong');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Google sign-in failed');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // "Forgot password" — opens a small dialog asking for email,
  // then asks Firebase to send a reset email. Firebase handles the rest.
  Future<void> _forgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final emailCtrl = TextEditingController(text: _emailController.text);
        return AlertDialog(
          title: const Text('Reset password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "We'll send a password reset link to your email.",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, emailCtrl.text),
              child: const Text('Send link'),
            ),
          ],
        );
      },
    );

    if (email == null || email.trim().isEmpty) return;

    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset link sent to $email. Check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Failed to send reset link');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.home_work, size: 64, color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                'Hostel SaaS',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp ? 'Create your account' : 'Welcome back',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),

                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your email';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a password';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),

                  // Confirm password — only on sign up
                  if (_isSignUp) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Confirm your password';
                        }
                        if (v != _passwordController.text) {
                          return "Passwords don't match";
                        }
                        return null;
                      },
                    ),
                  ],

                  // Forgot password — only on sign in
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),

                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? 'Sign up' : 'Sign in'),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _googleSignIn,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : "Don't have an account? Sign up",
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            // Wide layout: login form left, promo panel right
            return Row(
              children: [
                SizedBox(
                  width: 440,
                  child: Center(child: _buildForm(context)),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _PromoPanel()),
              ],
            );
          }
          return Center(child: _buildForm(context));
        },
      ),
    );
  }
}

// ─── Promotional panel shown beside login on wide screens ────────────────────

class _PromoPanel extends StatelessWidget {
  const _PromoPanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final features = [
      (Icons.bed_outlined, 'Room & Bed Management',
          'Track occupancy, maintenance, and bed allocation in real time.'),
      (Icons.people_outline, 'Guest & Tenant Portal',
          'Guests view invoices, raise complaints, and upload payment proofs.'),
      (Icons.bar_chart_outlined, 'AI CFO Analytics',
          '6-month revenue forecasts, collection efficiency, and cash-flow runway.'),
      (Icons.restaurant_menu_outlined, 'Daily Food Menu',
          'Publish today\'s breakfast, lunch, and dinner with availability notes.'),
      (Icons.notifications_outlined, 'Smart Notifications',
          'Overdue rent alerts, payment receipts, and maintenance requests.'),
      (Icons.monetization_on_outlined, 'Earn & Rewards',
          'Tenants earn wallet credits by watching short ads.'),
    ];

    return Container(
      color: cs.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Icon(Icons.home_work, size: 56, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Everything your hostel needs\nin one place.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Trusted by hostel owners across India.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 36),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(f.$1, size: 22, color: cs.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(f.$3,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const Spacer(),
        ],
      ),
    );
  }
}