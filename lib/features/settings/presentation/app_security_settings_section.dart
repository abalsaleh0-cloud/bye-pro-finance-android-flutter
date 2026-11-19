import 'package:expense_app/features/settings/data/app_security_service.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class AppSecuritySettingsSection extends StatefulWidget {
  const AppSecuritySettingsSection({super.key});

  @override
  State<AppSecuritySettingsSection> createState() =>
      _AppSecuritySettingsSectionState();
}

class _AppSecuritySettingsSectionState
    extends State<AppSecuritySettingsSection> {
  final AppSecurityService _security = AppSecurityService();
  bool _loading = true;
  bool _hasPin = false;
  bool _biometricEnabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final hasPin = await _security.hasPin;
      final biometric = await _security.isBiometricEnabled;
      if (!mounted) return;
      setState(() {
        _hasPin = hasPin;
        _biometricEnabled = hasPin && biometric;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _setPin() async {
    final strings = AppLocalizations.of(context)!;
    final oldPin = TextEditingController();
    final newPin = TextEditingController();
    final confirmPin = TextEditingController();
    var dialogError = '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_hasPin ? strings.securityChangePin : strings.securitySetPin),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasPin) ...[
                  TextField(
                    controller: oldPin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: strings.securityCurrentPinLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: newPin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: strings.securityNewPinLabel,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: strings.securityConfirmPinLabel,
                    counterText: '',
                  ),
                ),
                if (dialogError.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (_hasPin && !await _security.verifyPin(oldPin.text)) {
                  setDialogState(() => dialogError = strings.securityCurrentPinIncorrect);
                  return;
                }
                if (!RegExp(r'^\d{4,8}$').hasMatch(newPin.text)) {
                  setDialogState(() => dialogError = strings.securityPinLengthError);
                  return;
                }
                if (newPin.text != confirmPin.text) {
                  setDialogState(() => dialogError = strings.securityPinMismatch);
                  return;
                }
                try {
                  await _security.savePin(newPin.text);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (_) {
                  setDialogState(() => dialogError = strings.securityPinSaveFailed);
                }
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    oldPin.dispose();
    newPin.dispose();
    confirmPin.dispose();

    if (saved == true) {
      await _load();
      if (!mounted) return;
      _message(AppLocalizations.of(context)!.securityPinSavedNotice);
    }
  }

  Future<void> _removePin() async {
    final strings = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.securityRemovePinTitle),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: strings.securityCurrentPinLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.securityRemoveAction),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _security.removePin(controller.text);
        await _load();
        if (!mounted) return;
        _message(strings.securityPinRemovedNotice);
      } catch (_) {
        _message(strings.securityInvalidPin, error: true);
      }
    }
    controller.dispose();
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    if (_busy) return;
    final strings = AppLocalizations.of(context)!;
    if (enabled && !_hasPin) {
      _message(strings.securityPinRequiredForBiometrics, error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      if (enabled) {
        final available = await _security.isBiometricAvailable();
        if (!available) {
          _message(strings.securityBiometricUnavailable, error: true);
          return;
        }
        final accepted = await _security.enableBiometrics();
        if (!accepted) {
          _message(strings.securityBiometricNotEnabled);
          return;
        }
      } else {
        await _security.disableBiometrics();
      }

      if (mounted) {
        setState(() => _biometricEnabled = enabled);
        _message(enabled ? strings.securityBiometricEnabled : strings.securityBiometricDisabled);
      }
    } catch (_) {
      _message(strings.securityBiometricChangeFailed, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      key: const Key('app-security-settings-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.securityAppLockTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.securitySettingsDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.password_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                title: Text(_hasPin ? strings.securityChangePin : strings.securitySetPin),
                subtitle: Text(_hasPin ? strings.securityPinEnabled : strings.securityNotEnabled),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy ? null : _setPin,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  Icons.fingerprint_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                title: Text(strings.securityBiometricTitle),
                subtitle: Text(_biometricEnabled ? strings.securityBiometricEnabled : strings.securityPinRequiredForBiometrics),
                value: _biometricEnabled,
                onChanged: _busy ? null : _toggleBiometrics,
              ),
              if (_hasPin)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _removePin,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(strings.securityDisablePinProtection),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
