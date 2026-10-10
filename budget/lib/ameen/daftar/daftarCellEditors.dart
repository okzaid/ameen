import 'package:budget/ameen/daftar/daftarDialog.dart';
import 'package:budget/ameen/recentPlaces.dart';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Dialog editors for Daftar cells that need more than typing.

// Date, then time. Null when cancelled.
Future<DateTime?> pickDaftarDate(BuildContext context, DateTime current) async {
  DateTime? day = await showDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime(1990),
    lastDate: DateTime(2100),
  );
  if (day == null || !context.mounted) return null;
  TimeOfDay? time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  time ??= TimeOfDay.fromDateTime(current);
  return DateTime(
      day.year, day.month, day.day, time.hour, time.minute, current.second);
}

// A choice from a list. The result wraps the value so that "none" (null) can
// be told apart from cancelling (the whole result is null).
class DaftarChoice<T> {
  const DaftarChoice(this.value);
  final T value;
}

class _Option<T> {
  const _Option(this.value, this.label, {this.color, this.subtitle});
  final T value;
  final String label;
  final Color? color;
  final String? subtitle;
}

Future<DaftarChoice<T>?> _pickFromList<T>(
  BuildContext context, {
  required String title,
  required List<_Option<T>> options,
  required T current,
}) {
  return showDaftarDialog<DaftarChoice<T>>(
    context,
    title: title,
    maxWidth: 440,
    builder: (dialogContext) => _OptionList<T>(
        options: options,
        current: current,
        onPick: (value) {
          Navigator.of(dialogContext).pop(DaftarChoice<T>(value));
        }),
  );
}

class _OptionList<T> extends StatefulWidget {
  const _OptionList(
      {required this.options, required this.current, required this.onPick});
  final List<_Option<T>> options;
  final T current;
  final Function(T value) onPick;

  @override
  State<_OptionList<T>> createState() => _OptionListState<T>();
}

class _OptionListState<T> extends State<_OptionList<T>> {
  String search = "";

  @override
  Widget build(BuildContext context) {
    List<_Option<T>> shown = widget.options
        .where((o) => o.label.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.options.length > 8)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: TextInput(
              labelText: "daftar-search".tr(),
              icon: Icons.search_rounded,
              autoFocus: true,
              padding: EdgeInsetsDirectional.zero,
              onChanged: (value) => setState(() => search = value),
              onSubmitted: (_) {
                if (shown.length == 1) widget.onPick(shown.first.value);
              },
            ),
          ),
        for (_Option<T> option in shown)
          ListTile(
            dense: true,
            selected: option.value == widget.current,
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: option.color == null
                ? null
                : Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: option.color),
                  ),
            title: TextFont(text: option.label, fontSize: 15),
            subtitle: option.subtitle == null
                ? null
                : TextFont(
                    text: option.subtitle!,
                    fontSize: 13,
                    textColor: getColor(context, "textLight"),
                  ),
            onTap: () => widget.onPick(option.value),
          ),
      ],
    );
  }
}

// Main categories (not the special transfer one)
Future<DaftarChoice<String?>?> pickDaftarCategory(
  BuildContext context,
  Map<String, TransactionCategory> categories,
  String? current,
) {
  List<TransactionCategory> mains = categories.values
      .where((c) => c.mainCategoryPk == null && c.categoryPk != "0")
      .toList();
  return _pickFromList<String?>(
    context,
    title: "category".tr().capitalizeFirst,
    current: current,
    options: [
      for (TransactionCategory c in mains)
        _Option(c.categoryPk, c.name,
            color: HexColor(c.colour,
                defaultColor: Theme.of(context).colorScheme.primary))
    ],
  );
}

// Subcategories of [mainCategoryPk], plus "none"
Future<DaftarChoice<String?>?> pickDaftarSubcategory(
  BuildContext context,
  Map<String, TransactionCategory> categories,
  String? mainCategoryPk,
  String? current,
) {
  List<TransactionCategory> subs = categories.values
      .where(
          (c) => c.mainCategoryPk != null && c.mainCategoryPk == mainCategoryPk)
      .toList();
  return _pickFromList<String?>(
    context,
    title: "subcategory".tr(),
    current: current,
    options: [
      _Option<String?>(null, "daftar-none".tr()),
      for (TransactionCategory c in subs) _Option<String?>(c.categoryPk, c.name)
    ],
  );
}

// Accounts with the same currency as [currency]
Future<DaftarChoice<String>?> pickDaftarAccount(
  BuildContext context,
  AllWallets wallets,
  String current,
  String? currency,
) {
  List<TransactionWallet> same =
      wallets.indexedByPk.values.where((w) => w.currency == currency).toList();
  return _pickFromList<String>(
    context,
    title: "account".tr(),
    current: current,
    options: [
      for (TransactionWallet w in same)
        _Option(w.walletPk, w.name,
            subtitle: (w.currency ?? "").toUpperCase(),
            color: HexColor(w.colour,
                defaultColor: Theme.of(context).colorScheme.primary))
    ],
  );
}

// Multi-line note. Null when cancelled.
Future<String?> editDaftarNote(BuildContext context, String current) {
  String value = current;
  return showDaftarDialog<String>(
    context,
    title: "note".tr(),
    builder: (dialogContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextInput(
          labelText: "note".tr(),
          initialValue: current,
          autoFocus: true,
          keyboardType: TextInputType.multiline,
          minLines: 3,
          maxLines: 8,
          padding: EdgeInsetsDirectional.zero,
          onChanged: (text) => value = text,
        ),
        SizedBox(height: 14),
        Button(
          label: "save".tr(),
          expandedLayout: true,
          onTap: () => Navigator.of(dialogContext).pop(value),
        ),
      ],
    ),
  );
}

// Place name with recent places. "" removes it. Null when cancelled.
Future<String?> editDaftarPlace(BuildContext context, String current) {
  String value = current;
  ValueNotifier<String> typed = ValueNotifier("");
  return showDaftarDialog<String>(
    context,
    title: "daftar-place".tr(),
    maxWidth: 480,
    builder: (dialogContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecentPlaceChips(
          query: typed,
          onSelected: (place) => Navigator.of(dialogContext).pop(place),
        ),
        TextInput(
          labelText: "place-name".tr(),
          initialValue: current,
          autoFocus: true,
          textCapitalization: TextCapitalization.words,
          padding: EdgeInsetsDirectional.zero,
          onChanged: (text) {
            value = text;
            typed.value = text;
          },
          onSubmitted: (_) => Navigator.of(dialogContext).pop(value),
        ),
        SizedBox(height: 14),
        Button(
          label: "save".tr(),
          expandedLayout: true,
          onTap: () => Navigator.of(dialogContext).pop(value),
        ),
      ],
    ),
  );
}
