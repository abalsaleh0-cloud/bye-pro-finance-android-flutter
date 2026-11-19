import 'package:expense_app/features/settings/data/app_security_service.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class AppSecurityGate extends StatefulWidget {
  const AppSecurityGate({required this.child, super.key});

  final Widget child;

  @override
  State<AppSecurityGate> createState() => _AppSecurityGateState();
}

class _AppSecurityGateState extends State<AppSecurityGate> with WidgetsBindingObserver {
  final AppSecurityService _security = AppSecurityService();
  final TextEditingController _pinController = TextEditingController();

  bool _ready = false;
  bool _locked = false;
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _busy = false;
  String? _error;
  DateTime? _backgroundedAt;
  static const _backgroundRelockGracePeriod = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The PIN gate is enforced in profile/release builds. Debug sessions
    // (including Flutter widget tests) keep normal navigation accessible.
    if (!kDebugMode) {
      _loadSecurityState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode || !_ready || !_pinEnabled) return;

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null ||
        !shouldRelockAfterBackground(
          backgroundedAt,
          DateTime.now(),
          gracePeriod: _backgroundRelockGracePeriod,
        )) {
      return;
    }

    setState(() {
      _locked = true;
      _error = null;
      _pinController.clear();
    });
    if (_biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _authenticateBiometrics();
      });
    }
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
          _error = AppLocalizations.of(context)!.securityReadError;
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
        setState(() => _error = AppLocalizations.of(context)!.securityBiometricFailed);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context)!.securityUsePinMessage);
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
        setState(() => _error = AppLocalizations.of(context)!.securityInvalidPin);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context)!.securityVerifyFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) return widget.child;

    if (!_ready) {
      final strings = AppLocalizations.of(context)!;
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
                  strings.securityCheckingProtection,
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
    final strings = AppLocalizations.of(context)!;

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
                    strings.appLockedTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.appLockedDescription,
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
                      labelText: strings.pinCodeLabel,
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
                      child: Text(strings.unlockAction),
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
                          strings.useFingerprintAction,
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

/// Returns true when the app stayed in the background for at least the grace period.
bool shouldRelockAfterBackground(
  DateTime backgroundedAt,
  DateTime resumedAt, {
  Duration gracePeriod = const Duration(seconds: 30),
}) => !resumedAt.isBefore(backgroundedAt.add(gracePeriod));
