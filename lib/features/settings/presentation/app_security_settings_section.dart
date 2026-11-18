import 'package:expense_app/features/settings/data/app_security_service.dart';
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

  bool get _isEnglish =>
      Localizations.localeOf(context).languageCode == 'en';

  String _text(String ar, String en) => _isEnglish ? en : ar;

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

  void _message(String ar, String en, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_text(ar, en)),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _setPin() async {
    final oldPin = TextEditingController();
    final newPin = TextEditingController();
    final confirmPin = TextEditingController();
    var dialogError = '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_text(
            _hasPin ? 'تغيير رمز PIN' : 'تعيين رمز PIN',
            _hasPin ? 'Change PIN' : 'Set PIN',
          )),
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
                      labelText: _text('رمز PIN الحالي', 'Current PIN'),
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
                    labelText: _text(
                      'رمز PIN الجديد (4 إلى 8 أرقام)',
                      'New PIN (4–8 digits)',
                    ),
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
                    labelText: _text('تأكيد رمز PIN', 'Confirm PIN'),
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
              child: Text(_text('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                if (_hasPin && !await _security.verifyPin(oldPin.text)) {
                  setDialogState(() => dialogError = _text(
                    'رمز PIN الحالي غير صحيح.',
                    'Current PIN is incorrect.',
                  ));
                  return;
                }
                if (!RegExp(r'^\d{4,8}$').hasMatch(newPin.text)) {
                  setDialogState(() => dialogError = _text(
                    'يجب أن يتكون الرمز من 4 إلى 8 أرقام.',
                    'PIN must contain 4 to 8 digits.',
                  ));
                  return;
                }
                if (newPin.text != confirmPin.text) {
                  setDialogState(() => dialogError = _text(
                    'رمزا PIN غير متطابقين.',
                    'PIN codes do not match.',
                  ));
                  return;
                }
                try {
                  await _security.savePin(newPin.text);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (_) {
                  setDialogState(() => dialogError = _text(
                    'تعذر حفظ رمز PIN.',
                    'Could not save the PIN.',
                  ));
                }
              },
              child: Text(_text('حفظ', 'Save')),
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
      _message(
        'تم حفظ رمز PIN. سيُطلب عند فتح التطبيق.',
        'PIN saved. It will be required when the app opens.',
      );
    }
  }

  Future<void> _removePin() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text('إزالة رمز PIN', 'Remove PIN')),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: _text('أدخل رمز PIN الحالي', 'Enter current PIN'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_text('إزالة', 'Remove')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _security.removePin(controller.text);
        await _load();
        _message(
          'تمت إزالة PIN والبصمة.',
          'PIN and biometric protection were removed.',
        );
      } catch (_) {
        _message('رمز PIN غير صحيح.', 'Incorrect PIN.', error: true);
      }
    }
    controller.dispose();
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    if (_busy) return;
    if (enabled && !_hasPin) {
      _message(
        'يجب تعيين رمز PIN أولاً ليكون بديلاً آمناً للبصمة.',
        'Set a PIN first so it can be used as a secure fallback.',
        error: true,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (enabled) {
        final available = await _security.isBiometricAvailable();
        if (!available) {
          _message(
            'لا توجد بصمة مسجلة أو أن الجهاز لا يدعم التحقق الحيوي.',
            'No enrolled fingerprint or biometric authentication is available.',
            error: true,
          );
          return;
        }
        final accepted = await _security.enableBiometrics();
        if (!accepted) {
          _message('لم يتم تفعيل البصمة.', 'Biometric protection was not enabled.');
          return;
        }
      } else {
        await _security.disableBiometrics();
      }

      if (mounted) {
        setState(() => _biometricEnabled = enabled);
        _message(
          enabled ? 'تم تفعيل البصمة.' : 'تم إيقاف البصمة.',
          enabled ? 'Biometric protection enabled.' : 'Biometric protection disabled.',
        );
      }
    } catch (_) {
      _message(
        'تعذر تغيير إعداد البصمة.',
        'Could not change biometric settings.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    _text('قفل التطبيق', 'App lock'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _text(
                'يحمي رمز PIN بياناتك عند فتح التطبيق، ويمكن استخدام البصمة لفتحه بسرعة. تحفظ بيانات الأمان في التخزين الآمن للهاتف.',
                'Protect app access with a PIN and use biometrics for faster unlocking. Security credentials are stored in the phone secure storage.',
              ),
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
                title: Text(_hasPin
                    ? _text('تغيير رمز PIN', 'Change PIN')
                    : _text('تعيين رمز PIN', 'Set PIN')),
                subtitle: Text(_hasPin
                    ? _text('مفعّل — يُطلب عند فتح التطبيق', 'Enabled — required when the app opens')
                    : _text('غير مفعّل', 'Not enabled')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy ? null : _setPin,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  Icons.fingerprint_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                title: Text(_text('فتح التطبيق بالبصمة', 'Unlock with biometrics')),
                subtitle: Text(_biometricEnabled
                    ? _text('مفعّلة', 'Enabled')
                    : _text('استخدم البصمة مع وجود رمز PIN', 'Requires a PIN as fallback')),
                value: _biometricEnabled,
                onChanged: _busy ? null : _toggleBiometrics,
              ),
              if (_hasPin)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _removePin,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(_text('إيقاف حماية PIN', 'Disable PIN protection')),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
