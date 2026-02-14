import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart' show AppTheme;
import '../../widgets/healthdoc_logo.dart';
import '../../widgets/custom_button.dart';
import '../../providers/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    // Limit to 6 digits
    if (value.length > 6) {
      _codeController.value = TextEditingValue(
        text: value.substring(0, 6),
        selection: TextSelection.collapsed(offset: 6),
      );
      return;
    }

    // Auto-submit when all 6 digits are entered
    if (value.length == 6) {
      _handleVerify();
    }
  }


  Future<void> _handleVerify() async {
    final code = _codeController.text;
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(currentUserProvider.notifier);
      await authNotifier.verifyEmail(code);

      if (mounted) {
        // Refresh user to get updated emailVerified status
        await authNotifier.refreshUser();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        
        // Navigate to home
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        // Clear code field on error
        _codeController.clear();
        _focusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.resendVerificationCode(widget.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code has been sent to your email.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Clear code field
        _codeController.clear();
        _focusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      const Center(
                        child: HealthDocLogo(),
                      ),
                      const SizedBox(height: 48),
                      // Title
                      Text(
                        'Verify Your Email',
                        style: AppTheme.headingMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Instructions
                      Text(
                        'We\'ve sent a 6-digit verification code to',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.email,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Code Input Field with Custom Decoration
                      _OTPInputField(
                        controller: _codeController,
                        focusNode: _focusNode,
                        errorMessage: _errorMessage,
                        onChanged: _onCodeChanged,
                      ),
                      // Error Message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.errorColor),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.errorColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      // Verify Button
                      CustomButton(
                        text: 'Verify Email',
                        onPressed: _isLoading ? null : _handleVerify,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 16),
                      // Resend Code
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Didn\'t receive the code?',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: _isResending ? null : _handleResendCode,
                            child: _isResending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    'Resend',
                                    style: AppTheme.linkText,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Back to Login
                      TextButton(
                        onPressed: () {
                          context.go('/login');
                        },
                        child: Text(
                          'Back to Login',
                          style: AppTheme.linkText,
                        ),
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

class _OTPInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorMessage;
  final Function(String) onChanged;

  const _OTPInputField({
    required this.controller,
    required this.focusNode,
    this.errorMessage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return Stack(
          children: [
            // Hidden text field for input
            SizedBox(
              height: 60,
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 1),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
            // Visual representation
            GestureDetector(
              onTap: () => focusNode.requestFocus(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate responsive sizes
                  final screenWidth = constraints.maxWidth;
                  final spacing = 8.0; // Space between fields
                  final totalSpacing = spacing * 5; // 5 gaps between 6 fields
                  final safetyMargin = 2.0; // Safety margin to prevent overflow
                  // Calculate available width with safety margin
                  final availableWidth = screenWidth - totalSpacing - safetyMargin;
                  // Use floor to ensure no overflow, and ensure it fits
                  final calculatedWidth = availableWidth / 6;
                  final fieldWidth = calculatedWidth.floorToDouble().clamp(35.0, 45.0);
                  final fieldHeight = 60.0;
                  
                  return Container(
                    height: fieldHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(6, (index) {
                        final code = value.text;
                        final digit = index < code.length ? code[index] : '';
                        final isFocused = focusNode.hasFocus && index == code.length;
                        final hasError = errorMessage != null;

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: fieldWidth,
                              height: fieldHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border(
                                  left: BorderSide.none,
                                  right: BorderSide.none,
                                  top: BorderSide.none,
                                  bottom: BorderSide(
                                    color: hasError
                                        ? AppTheme.errorColor
                                        : (isFocused
                                            ? AppTheme.primaryColor
                                            : const Color(0xFFE0E0E0)),
                                    width: isFocused ? 3 : 2,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  digit,
                                  style: AppTheme.headingMedium.copyWith(
                                    fontSize: fieldWidth * 0.6,
                                    fontWeight: FontWeight.bold,
                                    color: digit.isEmpty
                                        ? Colors.transparent
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            if (index < 5) SizedBox(width: spacing),
                          ],
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
