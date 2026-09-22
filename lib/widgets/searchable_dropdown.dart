import 'package:flutter/material.dart';

class SearchableDropdown<T extends Object> extends StatefulWidget {
  final List<T> items;
  final String Function(T item) itemLabel;
  final T? initialValue;
  final ValueChanged<T?> onChanged;
  final String labelText;
  final String? hintText;
  final String? Function(T?)? validator;
  final bool enabled;

  const SearchableDropdown({
    super.key,
    required this.items,
    required this.itemLabel,
    required this.initialValue,
    required this.onChanged,
    required this.labelText,
    this.hintText,
    this.validator,
    this.enabled = true,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T extends Object>
    extends State<SearchableDropdown<T>> {
  late T? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _selected) {
      _selected = widget.initialValue;
    }
  }

  String _labelFor(T? value) {
    if (value == null) return '';
    return widget.itemLabel(value);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<T>(
      displayStringForOption: widget.itemLabel,
      initialValue: TextEditingValue(text: _labelFor(_selected)),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return widget.items;
        return widget.items.where(
          (item) => widget.itemLabel(item).toLowerCase().contains(query),
        );
      },
      onSelected: (value) {
        _selected = value;
        widget.onChanged(value);
      },
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: fieldController,
              focusNode: focusNode,
              enabled: widget.enabled,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText ?? 'Type to search',
                suffixIcon: const Icon(Icons.search),
              ),
              validator: (_) => widget.validator?.call(_selected),
              onChanged: (text) {
                if (_selected != null && text != _labelFor(_selected)) {
                  _selected = null;
                  widget.onChanged(null);
                }
              },
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
    );
  }
}
