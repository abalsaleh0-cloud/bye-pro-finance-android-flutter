import 'package:expense_app/features/settings/data/app_security_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class AppSecurityGate extends StatefulWidget {
  const AppSecurityGate({required this.child, super.key});

  final Widget child;

  @override
  State<AppSecurityGate> createState() => _AppSecurityGateState();
}

class _AppSecurityGateState extends State<AppSecurityGate> {
  final AppSecurityService _security = AppSecurityService();
  final TextEditingController _pinController = TextEditingController();

  bool _ready = false;
  bool _locked = false;
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _busy = false;
  String? _error;

  String _text(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : ar;

  @override
  void initState() {
    super.initState();
    // The PIN gate is enforced in profile/release builds. Debug sessions
    // (including Flutter widget tests) keep normal navigation accessible.
    if (!kDebugMode) {
      _loadSecurityState();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityState() async {
    try {
      final pinEnabled = await _security.hasPin;
      final biometricEnabled = await _security.isBiometricEnabled;
      if (!mounted) return;

      setState(() {
        _pinEnabled = pinEnabled;
        _biometricEnabled = biometricEnabled && pinEnabled;
        _locked = pinEnabled;
        _ready = true;
      });

      if (pinEnabled && biometricEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _authenticateBiometrics();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ready = true;
          _error = _text(
            'تعذر قراءة إعدادات الحماية. أغلق التطبيق وافتحه مجدداً.',
            'Unable to read security settings. Restart the app.',
          );
        });
      }
    }
  }

  Future<void> _authenticateBiometrics() async {
    if (_busy || !_biometricEnabled || !_locked) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final authenticated = await _security.authenticateBiometrics();
      if (!mounted) return;
      if (authenticated) {
        setState(() => _locked = false);
      } else {
        setState(() => _error = _text(
          'تعذر التحقق بالبصمة. أدخل رمز PIN للمتابعة.',
          'Biometric verification failed. Enter your PIN to continue.',
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = _text(
          'استخدم رمز PIN لفتح التطبيق.',
          'Use your PIN to unlock the app.',
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyPin() async {
    if (_busy || _pinController.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final valid = await _security.verifyPin(_pinController.text);
      if (!mounted) return;
      if (valid) {
        setState(() => _locked = false);
      } else {
        _pinController.clear();
        setState(() => _error = _text('رمز PIN غير صحيح.', 'Incorrect PIN.'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = _text(
          'تعذر التحقق من الرمز. حاول مرة أخرى.',
          'Unable to verify the PIN. Try again.',
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) return widget.child;

    if (!_ready) {
      final isEnglish = Localizations.localeOf(context).languageCode == 'en';
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 38,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  isEnglish
                      ? 'Checking app protection…'
                      : 'جارٍ التحقق من حماية التطبيق…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_locked || !_pinEnabled) return widget.child;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: scheme.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    isEnglish ? 'App locked' : 'التطبيق مقفل',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEnglish
                        ? 'Enter your PIN to access your financial data.'
                        : 'أدخل رمز PIN للوصول إلى بياناتك المالية.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinController,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'PIN code' : 'رمز PIN',
                      counterText: '',
                      suffixIcon: const Icon(Icons.password_rounded),
                    ),
                    onSubmitted: (_) => _verifyPin(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _verifyPin,
                      child: Text(isEnglish ? 'Unlock' : 'فتح التطبيق'),
                    ),
                  ),
                  if (_biometricEnabled) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _authenticateBiometrics,
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: Text(
                          isEnglish ? 'Use fingerprint' : 'استخدام البصمة',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
