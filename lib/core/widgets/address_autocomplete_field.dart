import 'dart:async';

import 'package:flutter/material.dart';

import '../services/address_suggestion_service.dart';
import '../theme/app_colors.dart';

/// An address text field that suggests full addresses as the user types,
/// backed by [AddressSuggestionService] (OpenStreetMap Nominatim).
///
/// Wraps the caller's [controller] so the typed/selected value flows straight
/// into the surrounding form. [search] is injectable for tests. Suggestions are
/// best-effort: if the lookup fails or returns nothing, the field behaves like
/// an ordinary text input.
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool enabled;
  final int maxLines;
  final int minLines;
  final TextInputAction? textInputAction;

  /// Returns suggestions for a query. Defaults to the live Nominatim service.
  final Future<List<String>> Function(String) search;

  AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.decoration,
    this.enabled = true,
    this.maxLines = 2,
    this.minLines = 1,
    this.textInputAction,
    Future<List<String>> Function(String)? search,
  }) : search = search ?? AddressSuggestionService().search;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  Completer<List<String>>? _pending;

  @override
  void dispose() {
    _debounce?.cancel();
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.complete(const []);
    }
    _focusNode.dispose();
    super.dispose();
  }

  Future<Iterable<String>> _optionsBuilder(TextEditingValue value) {
    _debounce?.cancel();
    // Resolve any in-flight call so its future never dangles.
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.complete(const []);
    }

    final query = value.text;
    final completer = Completer<List<String>>();
    _pending = completer;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await widget.search(query);
      if (!completer.isCompleted) completer.complete(results);
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;
        return RawAutocomplete<String>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          optionsBuilder: _optionsBuilder,
          displayStringForOption: (option) => option,
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  enabled: widget.enabled,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  textInputAction: widget.textInputAction,
                  decoration: widget.decoration,
                  onSubmitted: (_) => onFieldSubmitted(),
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(14),
                shadowColor: AppColors.shadowDeep,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 240,
                    maxWidth: fieldWidth,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
