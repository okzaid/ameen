import 'package:budget/colors.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// A searchable currency list that works inside bottom sheets (including a
// sheet opened from another sheet). Returns the lowercase currency key.
Future<String?> pickCurrencySheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? selected,
  List<String> pinned = const [],
}) async {
  String? result;
  await openBottomSheet(
    context,
    fullSnap: true,
    PopupFramework(
      title: title,
      subtitle: subtitle,
      child: _CurrencyList(
        selected: selected,
        pinned: pinned,
        onSelected: (key) {
          result = key;
          popRoute(context);
        },
      ),
    ),
  );
  return result;
}

class _CurrencyList extends StatefulWidget {
  const _CurrencyList({
    required this.selected,
    required this.pinned,
    required this.onSelected,
  });
  final String? selected;
  final List<String> pinned;
  final Function(String) onSelected;

  @override
  State<_CurrencyList> createState() => _CurrencyListState();
}

class _CurrencyListState extends State<_CurrencyList> {
  String search = "";

  bool matches(String key) {
    if (search == "") return true;
    String q = search.toLowerCase();
    Map info = currenciesJSON[key] ?? {};
    return key.contains(q) ||
        (info["Currency"] ?? "").toString().toLowerCase().contains(q) ||
        (info["CountryName"] ?? "").toString().toLowerCase().contains(q) ||
        (info["Symbol"] ?? "").toString().toLowerCase() == q;
  }

  @override
  Widget build(BuildContext context) {
    List<String> keys = currenciesJSON.keys.toList();
    List<String> pinned =
        widget.pinned.where((k) => currenciesJSON.containsKey(k)).toList();
    // Real currencies (with a country) before crypto tokens
    bool isFiat(String k) =>
        (currenciesJSON[k]?["CountryName"] ?? "").toString() != "";
    List<String> rest = [
      ...keys.where((k) => !pinned.contains(k) && isFiat(k)),
      ...keys.where((k) => !pinned.contains(k) && !isFiat(k)),
    ];
    List<String> shown = [...pinned, ...rest].where(matches).toList();
    // An exact code match ("usd") comes first
    String exact = search.toLowerCase();
    if (shown.remove(exact)) shown.insert(0, exact);
    return Column(
      children: [
        TextInput(
          labelText: "search-currencies-placeholder".tr(),
          icon: Icons.search_rounded,
          onChanged: (value) => setState(() => search = value.trim()),
          padding: EdgeInsetsDirectional.zero,
        ),
        SizedBox(height: 10),
        for (String key in shown.take(search == "" ? 60 : 200))
          _CurrencyRow(
            currencyKey: key,
            selected: key == widget.selected,
            onTap: () => widget.onSelected(key),
          ),
      ],
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow(
      {required this.currencyKey, required this.selected, required this.onTap});
  final String currencyKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Map info = currenciesJSON[currencyKey] ?? {};
    String symbol = (info["Symbol"] ?? "").toString();
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 3),
      child: Tappable(
        borderRadius: 14,
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : getColor(context, "lightDarkAccentHeavyLight"),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: TextFont(
                  text: currencyKey.toUpperCase(),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Expanded(
                child: TextFont(
                  text: [info["Currency"], info["CountryName"]]
                      .where((e) => e != null && e.toString() != "")
                      .join(" · "),
                  fontSize: 14,
                  maxLines: 1,
                  textColor: getColor(context, "textLight"),
                ),
              ),
              SizedBox(width: 8),
              TextFont(text: symbol, fontSize: 18),
            ],
          ),
        ),
      ),
    );
  }
}
