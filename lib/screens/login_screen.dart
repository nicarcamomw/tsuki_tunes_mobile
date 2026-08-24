import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithGoogle();
    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al iniciar sesión',
              style: GoogleFonts.spaceGrotesk(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Title
                Text(
                  'TSUKI',
                  style: GoogleFonts.orbitron(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent,
                    letterSpacing: 8,
                  ),
                ),
                Text(
                  'TUNES',
                  style: GoogleFonts.orbitron(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textBright,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 3,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 16),
                Text(
                  'SYSTEM_INIT // AWAITING AUTH',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 64),

                // Google Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accent, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      backgroundColor: AppColors.accentDim,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.login, color: AppColors.accent, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'INICIAR CON GOOGLE',
                                style: GoogleFonts.orbitron(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Conecta tu cuenta para sincronizar\ntu biblioteca entre dispositivos',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
