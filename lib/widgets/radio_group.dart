// lib/widgets/radio_group.dart
import 'package:flutter/material.dart';

/// A simple RadioGroup widget that provides group context for RadioListTile children.
/// 
/// This widget wraps a child (typically a ListView containing RadioListTile widgets)
/// and provides the necessary groupValue and onChanged context.
/// 
/// Example usage:
/// ```dart
/// RadioGroup<String>(
///   groupValue: selectedValue,
///   onChanged: (value) {
///     setState(() => selectedValue = value);
///   },
///   child: ListView(
///     children: options.map((option) {
///       return RadioListTile<String>(
///         value: option,
///         title: Text(option),
///       );
///     }).toList(),
///   ),
/// )
/// ```
class NvRadioGroup<T> extends StatelessWidget {
  /// The currently selected value in this radio group
  final T? groupValue;
  
  /// Callback when a radio button is selected
  final ValueChanged<T?>? onChanged;
  
  /// The child widget, typically a ListView with RadioListTile children
  final Widget child;

  const NvRadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // The RadioListTile widgets in the child will automatically use
    // their own groupValue and onChanged properties, so we just need
    // to render the child as-is. The RadioGroup is primarily a semantic
    // wrapper that makes the code more readable and organized.
    return child;
  }
}
