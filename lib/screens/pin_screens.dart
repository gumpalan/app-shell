import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_lock_service.dart';

/// Screen mandiri untuk membuat atau mengubah PIN aplikasi (6 digit).
class PinSetupScreen extends StatefulWidget {
  final AppLockService appLockService;

  const PinSetupScreen({super.key, required this.appLockService});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _error;

  void _onKeyPress(String val) {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      if (!_isConfirming) {
        if (_firstPin.length < 6) {
          _firstPin += val;
          if (_firstPin.length == 6) {
            _isConfirming = true;
          }
        }
      } else {
        if (_confirmPin.length < 6) {
          _confirmPin += val;
          if (_confirmPin.length == 6) {
            _handleFinish();
          }
        }
      }
    });
  }

  void _onDelete() {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      if (!_isConfirming) {
        if (_firstPin.isNotEmpty) {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
        }
      }
    });
  }

  Future<void> _handleFinish() async {
    if (_firstPin == _confirmPin) {
      await widget.appLockService.setPin(_firstPin);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'PIN tidak cocok. Silakan coba lagi.';
        _confirmPin = '';
        _firstPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentInput = _isConfirming ? _confirmPin : _firstPin;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isConfirming ? 'Konfirmasi PIN' : 'Buat PIN Baru'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(
              _isConfirming
                  ? Icons.lock_outline_rounded
                  : Icons.shield_outlined,
              size: 48,
              color: colors.onSurface.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              _isConfirming
                  ? 'Masukkan ulang 6 digit PIN'
                  : 'Buat 6 digit PIN keamanan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isConfirming
                  ? 'Pastikan digit sesuai dengan yang pertama'
                  : 'PIN ini digunakan untuk membuka aplikasi',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),

            _PinDotsIndicator(
              length: 6,
              filledCount: currentInput.length,
              hasError: _error != null,
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: colors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const Spacer(),

            _NumPad(onKeyPress: _onKeyPress, onDelete: _onDelete),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Screen mandiri ketika aplikasi dalam kondisi terkunci.
/// Otomatis memicu biometrik jika aktif, dan menyediakan tombol minta sidik jari kembali.
class PinLockScreen extends StatefulWidget {
  final AppLockService appLockService;
  final VoidCallback onUnlocked;

  const PinLockScreen({
    super.key,
    required this.appLockService,
    required this.onUnlocked,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _inputPin = '';
  String? _error;
  bool _biometricAvailable = false;
  bool _isPromptingBiometric = false;

  @override
  void initState() {
    super.initState();
    _initBiometricsAndPrompt();
  }

  Future<void> _initBiometricsAndPrompt() async {
    final bioEnabled = await widget.appLockService.isBiometricEnabled();
    final canBio = await widget.appLockService.canAuthenticateWithBiometrics();
    final shouldPrompt = bioEnabled && canBio;

    if (mounted) {
      setState(() => _biometricAvailable = shouldPrompt);
    }

    if (shouldPrompt) {
      _promptBiometric();
    }
  }

  Future<void> _promptBiometric() async {
    if (_isPromptingBiometric) return;
    _isPromptingBiometric = true;
    try {
      final success = await widget.appLockService.authenticateBiometrics(
        reason: 'Pindai sidik jari untuk membuka Gumpalan',
      );
      if (success && mounted) {
        widget.onUnlocked();
      }
    } finally {
      _isPromptingBiometric = false;
    }
  }

  void _onKeyPress(String val) {
    if (_inputPin.length >= 6) return;
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      _inputPin += val;
    });

    if (_inputPin.length == 6) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_inputPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      _inputPin = _inputPin.substring(0, _inputPin.length - 1);
    });
  }

  Future<void> _verifyPin() async {
    final ok = await widget.appLockService.verifyPin(_inputPin);
    if (ok) {
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'PIN salah';
        _inputPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_rounded,
                size: 34,
                color: colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Masukkan PIN',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aplikasi diamankan dengan kode keamanan',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),

            _PinDotsIndicator(
              length: 6,
              filledCount: _inputPin.length,
              hasError: _error != null,
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: colors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const Spacer(),

            _NumPad(
              onKeyPress: _onKeyPress,
              onDelete: _onDelete,
              leftActionIcon: _biometricAvailable
                  ? Icons.fingerprint_rounded
                  : null,
              onLeftAction: _biometricAvailable ? _promptBiometric : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Indikator visual titik-titik PIN.
class _PinDotsIndicator extends StatelessWidget {
  final int length;
  final int filledCount;
  final bool hasError;

  const _PinDotsIndicator({
    required this.length,
    required this.filledCount,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isFilled = index < filledCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? colors.error
                : isFilled
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.15),
            border: Border.all(
              color: hasError
                  ? colors.error
                  : isFilled
                  ? colors.primary
                  : colors.outlineVariant.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}

/// Komponen keypad angka 0-9 modern dan ergonomis.
class _NumPad extends StatelessWidget {
  final ValueChanged<String> onKeyPress;
  final VoidCallback onDelete;
  final IconData? leftActionIcon;
  final VoidCallback? onLeftAction;

  const _NumPad({
    required this.onKeyPress,
    required this.onDelete,
    this.leftActionIcon,
    this.onLeftAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          _buildRow(['1', '2', '3'], context),
          const SizedBox(height: 16),
          _buildRow(['4', '5', '6'], context),
          const SizedBox(height: 16),
          _buildRow(['7', '8', '9'], context),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: leftActionIcon != null
                    ? IconButton(
                        icon: Icon(leftActionIcon, size: 32),
                        color: colors.onSurface.withValues(alpha: 0.8),
                        onPressed: onLeftAction,
                      )
                    : const SizedBox.shrink(),
              ),
              _buildDigitButton('0', context),
              SizedBox(
                width: 72,
                height: 72,
                child: IconButton(
                  icon: const Icon(Icons.backspace_outlined, size: 26),
                  color: colors.onSurface.withValues(alpha: 0.8),
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> digits, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d, context)).toList(),
    );
  }

  Widget _buildDigitButton(String digit, BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onKeyPress(digit),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
