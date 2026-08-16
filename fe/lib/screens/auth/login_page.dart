import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_provider.dart';
import '../admin/admin_shell.dart';
import 'password_gate.dart';
import '../messages/public_message_sheet.dart';
import '../user/user_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _hasError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _hasError = false;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Navigate based on role
      if (authProvider.isAdmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            // Behind the gate: an account still on the default password
            // has to replace it before it reaches the console.
            builder: (_) => const PasswordGate(child: AdminShell()),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PasswordGate(child: UserShell()),
          ),
        );
      }
    } else {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      // No AppBar on this screen, so nothing reserves room for the system
      // status bar and the form would render under the clock and battery.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;

            if (isMobile) {
              return _buildMobileLayout();
            } else {
              return _buildDesktopLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [const SizedBox(height: 40), _buildFormContent()],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Panel: Form Container (40%)
        Expanded(
          flex: 4,
          child: Container(
            color: AppTheme.surface,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildFormContent(),
                ),
              ),
            ),
          ),
        ),

        // Right Panel: Hero Image (60%)
        Expanded(flex: 6, child: _buildHeroPanel()),
      ],
    );
  }

  Widget _buildFormContent() {
    final authProvider = Provider.of<AuthProvider>(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Branding / Header
          Row(
            children: [
              Image.asset('assets/branding/brin_logo.png', width: 40, height: 40),
              const SizedBox(width: 12),
              Text('BRIN', style: Theme.of(context).textTheme.headlineLarge),
            ],
          ),
          const SizedBox(height: 32),

          Text(
            'Institutional Access',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Secure authentication gateway for authorized researchers.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 4),
          Container(width: 40, height: 4, color: AppTheme.primary),
          const SizedBox(height: 32),

          // Email Field
          Text('EMAIL ADDRESS', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Enter your institutional email',
              errorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppTheme.error, width: 2),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppTheme.error, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email is required';
              }
              if (!value.contains('@')) {
                return 'Enter a valid email';
              }
              return null;
            },
            onChanged: (_) {
              if (_hasError) {
                setState(() {
                  _hasError = false;
                });
                authProvider.clearError();
              }
            },
          ),
          const SizedBox(height: 24),

          // Password Field
          Text('PASSWORD', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              errorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppTheme.error, width: 2),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppTheme.error, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.textMuted,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
            onChanged: (_) {
              if (_hasError) {
                setState(() {
                  _hasError = false;
                });
                authProvider.clearError();
              }
            },
          ),

          // Error Message
          if (_hasError && authProvider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                authProvider.errorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.error),
              ),
            ),

          const SizedBox(height: 32),

          // Submit Button
          ElevatedButton(
            onPressed: authProvider.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: AppTheme.textMuted,
            ),
            child: authProvider.isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: AppTheme.surface,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'AUTHENTICATING...',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.surface,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'AUTHENTICATE',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.surface,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),

          const SizedBox(height: 32),

          // Footer Links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  // Navigate back to landing page
                  Navigator.pop(context);
                },
                child: Text(
                  'Request Access',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text(' | ', style: Theme.of(context).textTheme.bodySmall),
              TextButton(
                // Opens the guest form, not the in-app one: the usual reason
                // to press this is not being able to sign in.
                onPressed: () => showPublicMessageSheet(context),
                child: Text(
                  'IT Support',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPanel() {
    return Container(
      color: AppTheme.textPrimary,
      child: Stack(
        children: [
          // Base gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary,
                  AppTheme.primaryDark,
                  AppTheme.textPrimary,
                ],
              ),
            ),
          ),

          // Pattern overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/images/pattern.png',
                repeat: ImageRepeat.repeat,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),

          // Content
          Positioned(
            bottom: 48,
            right: 48,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Deep Learning Hub',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.surface,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Empowering rigorous academic research through scalable neural network infrastructure.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.surface.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),

          // BRIN Icon watermark
          Positioned(
            top: 48,
            right: 48,
            child: Icon(
              Icons.science,
              size: 200,
              color: AppTheme.surface.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }
}
