import 'package:flutter/material.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_chip.dart';
import '../../../../ui/widgets/ink_segmented.dart';
import '../../../../ui/widgets/ink_text_field.dart';

/// Shared invite expiration selector supporting presets and a custom duration
/// in hours or days.
class InviteExpirationPicker extends StatefulWidget {
  static const List<int> presetHours = <int>[24, 72, 168];
  static const int minHours = 1;
  static const int maxHours = 8760; // 365 days
  static const int maxDays = 365;

  final int valueHours;
  final ValueChanged<int> onChanged;
  final ValueChanged<bool>? onValidityChanged;
  final bool enabled;

  const InviteExpirationPicker({
    super.key,
    required this.valueHours,
    required this.onChanged,
    this.onValidityChanged,
    this.enabled = true,
  });

  static int? parseCustomHours({
    required String rawAmount,
    required bool isDays,
  }) {
    final amount = int.tryParse(rawAmount.trim());
    if (amount == null || amount < 1) return null;
    if (isDays) {
      if (amount > maxDays) return null;
      return amount * 24;
    }
    if (amount > maxHours) return null;
    return amount;
  }

  static String formatDuration(int hours) {
    if (hours >= 24 && hours % 24 == 0) {
      final days = hours ~/ 24;
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
    return '$hours ${hours == 1 ? 'hour' : 'hours'}';
  }

  @override
  State<InviteExpirationPicker> createState() => _InviteExpirationPickerState();
}

class _InviteExpirationPickerState extends State<InviteExpirationPicker> {
  late final TextEditingController _amountController;
  bool _isCustomMode = false;
  bool _isDays = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _syncFromValue(widget.valueHours, forcePresetDetection: true);
  }

  @override
  void didUpdateWidget(covariant InviteExpirationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueHours != widget.valueHours) {
      final isPreset = InviteExpirationPicker.presetHours.contains(
        widget.valueHours,
      );
      if (!isPreset && !_isCustomMode) {
        _syncFromValue(widget.valueHours, forcePresetDetection: true);
      } else if (_isCustomMode) {
        final currentParsed = InviteExpirationPicker.parseCustomHours(
          rawAmount: _amountController.text,
          isDays: _isDays,
        );
        if (currentParsed != widget.valueHours) {
          _syncFromValue(widget.valueHours, forcePresetDetection: false);
        }
      }
    }
  }

  void _syncFromValue(int hours, {required bool forcePresetDetection}) {
    final clamped = hours.clamp(
      InviteExpirationPicker.minHours,
      InviteExpirationPicker.maxHours,
    );
    if (forcePresetDetection) {
      _isCustomMode = !InviteExpirationPicker.presetHours.contains(clamped);
    }
    if (clamped >= 24 && clamped % 24 == 0) {
      _isDays = true;
      _amountController.text = '${clamped ~/ 24}';
    } else {
      _isDays = false;
      _amountController.text = '$clamped';
    }
    _errorText = null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectPreset(int hours) {
    if (!widget.enabled) return;
    setState(() {
      _isCustomMode = false;
      _errorText = null;
      _syncFromValue(hours, forcePresetDetection: false);
    });
    widget.onValidityChanged?.call(true);
    widget.onChanged(hours);
  }

  void _enterCustomMode() {
    if (!widget.enabled) return;
    setState(() {
      _isCustomMode = true;
      _syncFromValue(widget.valueHours, forcePresetDetection: false);
    });
    widget.onValidityChanged?.call(true);
  }

  void _onCustomInputChanged() {
    final parsed = InviteExpirationPicker.parseCustomHours(
      rawAmount: _amountController.text,
      isDays: _isDays,
    );
    if (parsed == null) {
      setState(() {
        _errorText = _isDays
            ? 'Enter 1 to ${InviteExpirationPicker.maxDays} days'
            : 'Enter 1 to ${InviteExpirationPicker.maxHours} hours';
      });
      widget.onValidityChanged?.call(false);
      return;
    }
    setState(() {
      _errorText = null;
    });
    widget.onValidityChanged?.call(true);
    widget.onChanged(parsed);
  }

  String _presetLabel(int hours) {
    return switch (hours) {
      24 => '24 hours',
      72 => '3 days',
      168 => '7 days',
      _ => InviteExpirationPicker.formatDuration(hours),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: InkSpacing.s8,
          runSpacing: InkSpacing.s8,
          children: [
            for (final preset in InviteExpirationPicker.presetHours)
              InkChip(
                label: _presetLabel(preset),
                selected: !_isCustomMode && widget.valueHours == preset,
                onTap: widget.enabled ? () => _selectPreset(preset) : null,
              ),
            InkChip(
              label: _isCustomMode
                  ? 'Custom (${InviteExpirationPicker.formatDuration(widget.valueHours)})'
                  : 'Custom',
              selected: _isCustomMode,
              onTap: widget.enabled ? _enterCustomMode : null,
            ),
          ],
        ),
        if (_isCustomMode) ...[
          const SizedBox(height: InkSpacing.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: InkTextField(
                  controller: _amountController,
                  enabled: widget.enabled,
                  hintText: _isDays ? 'Days' : 'Hours',
                  errorText: _errorText,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _onCustomInputChanged(),
                ),
              ),
              const SizedBox(width: InkSpacing.s12),
              Expanded(
                flex: 4,
                child: InkSegmented(
                  labels: const ['Hours', 'Days'],
                  selectedIndex: _isDays ? 1 : 0,
                  onChanged: (index) {
                    if (!widget.enabled) return;
                    final nextIsDays = index == 1;
                    if (nextIsDays == _isDays) return;
                    final currentValue = int.tryParse(
                      _amountController.text.trim(),
                    );
                    setState(() {
                      _isDays = nextIsDays;
                      if (currentValue != null && currentValue > 0) {
                        if (nextIsDays) {
                          final days = ((currentValue + 23) ~/ 24).clamp(
                            1,
                            InviteExpirationPicker.maxDays,
                          );
                          _amountController.text = '$days';
                        } else {
                          final hrs = (currentValue * 24).clamp(
                            1,
                            InviteExpirationPicker.maxHours,
                          );
                          _amountController.text = '$hrs';
                        }
                      }
                    });
                    _onCustomInputChanged();
                  },
                ),
              ),
            ],
          ),
          if (_errorText == null) ...[
            const SizedBox(height: InkSpacing.s8),
            Text(
              'Invites will expire after ${InviteExpirationPicker.formatDuration(widget.valueHours)}.',
              style: InkType.caption(tokens.inkMuted),
            ),
          ],
        ],
      ],
    );
  }
}
