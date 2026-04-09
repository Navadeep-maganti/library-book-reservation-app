import 'package:flutter/material.dart';
import '../../core/widgets/app_ui.dart';
import 'register_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _showError = false;
  String _errorMessage = "Invalid credentials. Please try again";
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _showError = true;
        _errorMessage = "Please enter username and password.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showError = false;
    });

    try {
      final role = await AuthService.login(username, password);
      if (!mounted) return;

      final route = role == "librarian" ? "/librarian" : "/student";
      Navigator.pushReplacementNamed(context, route);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showError = true;
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F7FB), Color(0xFFE0F2FE), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 18),
                          const AppPageHeader(
                            title: "NIT Andhra Pradesh",
                            subtitle:
                                "Access circulation, reservations, fines, and reading activity from one place.",
                            icon: Icons.auto_stories_rounded,
                            badges: [
                              AppHeaderBadge(
                                label: "Access",
                                value: "Student + Librarian",
                              ),
                              AppHeaderBadge(
                                label: "Experience",
                                value: "Fast and live",
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Welcome back",
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontSize: 28),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Sign in with your student credentials to continue to the library dashboard.",
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 22),
                                  TextField(
                                    controller: _usernameController,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: "Username or Student ID",
                                      hintText: "e.g. 202400123",
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    onSubmitted: (_) {
                                      if (!_isLoading) {
                                        _handleLogin();
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: "Password",
                                      hintText: "Enter your password",
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (_showError)
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.red.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage,
                                              style: const TextStyle(
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_showError) const SizedBox(height: 14),
                                  Column(
                                    children: [
                                      Text(
                                        "Use your registered account details. Contact the library if you are locked out.",
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF64748B),
                                              height: 1.45,
                                            ),
                                      ),
                                      // const SizedBox(height: 6),
                                      // TextButton(
                                      //   onPressed: () {},
                                      //   child: const Text("Forgot password?"),
                                      // ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                   SizedBox(
                                     width: double.infinity,
                                     child: FilledButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : _handleLogin,
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.login_rounded),
                                      label: Text(
                                        _isLoading
                                            ? "Signing in..."
                                            : "Continue to library",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _isLoading
                                            ? null
                                            : () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const RegisterScreen(),
                                                  ),
                                                );
                                              },
                                        icon: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                        ),
                                        label: const Text("Create account"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ),
                          const SizedBox(height: 16),
                          const AppInfoBanner(
                            icon: Icons.support_agent_outlined,
                            message:
                                "Need help accessing your account? Reach the library support desk for password reset and role issues.",
                            color: Color(0xFF1D4ED8),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              "NIT AP Library System v1.0",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
