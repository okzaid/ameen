import 'package:budget/ameen/daftar/daftarDialog.dart';
import 'package:budget/ameen/daftar/daftarModel.dart';
import 'package:budget/ameen/daftar/daftarPage.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Daftar's filter editor: pick a column, then the condition for its kind
// (text, list of values, amount range, date range, paid).

String _textModeLabel(DaftarTextMode mode) =>
    "daftar-" +
    {
      DaftarTextMode.contains: "contains",
      DaftarTextMode.equals: "equals",
      DaftarTextMode.startsWith: "starts-with",
      DaftarTextMode.isEmpty: "is-empty",
      DaftarTextMode.isNotEmpty: "is-not-empty",
    }[mode]!;

// Distinct values of a set column: key → label, by label
List<MapEntry<String?, String>> daftarValuesOf(
    List<DaftarRow> rows, DaftarColumn column) {
  Map<String?, String> values = {};
  for (DaftarRow row in rows) {
    String? key = row.keyOf(column);
    if (values.containsKey(key)) continue;
    String label;
    switch (column) {
      case DaftarColumn.category:
        label = row.categoryName;
        break;
      case DaftarColumn.subcategory:
        label = row.subcategoryName;
        break;
      case DaftarColumn.account:
        label = row.walletName;
        break;
      case DaftarColumn.type:
        label = daftarTypeLabel(row.type);
        break;
      default:
        label = row.textOf(column);
    }
    values[key] = label == "" ? "daftar-none".tr() : label;
  }
  return values.entries.toList()
    ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
}

// "Category: Food, Transit" — shown on the filter chips
String describeDaftarFilter(DaftarFilter filter, List<DaftarRow> rows) {
  String column = daftarColumnLabel(filter.column);
  if (filter is DaftarTextFilter) {
    String mode = _textModeLabel(filter.mode).tr();
    if (filter.mode == DaftarTextMode.isEmpty ||
        filter.mode == DaftarTextMode.isNotEmpty) return column + " " + mode;
    return column + " " + mode + " \"" + filter.value + "\"";
  }
  if (filter is DaftarSetFilter) {
    Map<String?, String> labels = {
      for (MapEntry<String?, String> e in daftarValuesOf(rows, filter.column))
        e.key: e.value
    };
    List<String> names = [
      for (String? key in filter.values) labels[key] ?? "?"
    ];
    String shown = names.take(3).join(", ");
    if (names.length > 3) shown += " +" + (names.length - 3).toString();
    return column + ": " + shown;
  }
  if (filter is DaftarRangeFilter) {
    String min = filter.min == null ? "…" : filter.min!.toString();
    String max = filter.max == null ? "…" : filter.max!.toString();
    return column + ": " + min + " – " + max;
  }
  if (filter is DaftarDateFilter) {
    DateFormat format = DateFormat.yMMMd();
    String start = filter.start == null ? "…" : format.format(filter.start!);
    String end = filter.end == null ? "…" : format.format(filter.end!);
    return column + ": " + start + " – " + end;
  }
  if (filter is DaftarBoolFilter)
    return column + ": " + (filter.value ? "daftar-yes" : "daftar-no").tr();
  return column;
}

Future<DaftarFilter?> openDaftarFilterEditor(
  BuildContext context, {
  required List<DaftarRow> rows,
  DaftarColumn? column,
  DaftarFilter? initial,
}) async {
  return showDaftarDialog<DaftarFilter>(
    context,
    title: "daftar-add-filter".tr(),
    builder: (dialogContext) => _FilterEditor(
      rows: rows,
      column: column,
      initial: initial,
      onDone: (filter) => Navigator.of(dialogContext).pop(filter),
    ),
  );
}

class _FilterEditor extends StatefulWidget {
  const _FilterEditor({
    required this.rows,
    required this.column,
    required this.initial,
    required this.onDone,
  });
  final List<DaftarRow> rows;
  final DaftarColumn? column;
  final DaftarFilter? initial;
  final Function(DaftarFilter filter) onDone;

  @override
  State<_FilterEditor> createState() => _FilterEditorState();
}

class _FilterEditorState extends State<_FilterEditor> {
  late DaftarColumn? column = widget.column;

  // text
  DaftarTextMode mode = DaftarTextMode.contains;
  String text = "";
  // set
  Set<String?> chosen = {};
  String valueSearch = "";
  // range
  String minText = "";
  String maxText = "";
  // date
  DateTime? start;
  DateTime? end;
  // bool
  bool paid = true;

  @override
  void initState() {
    super.initState();
    DaftarFilter? initial = widget.initial;
    if (initial is DaftarTextFilter) {
      mode = initial.mode;
      text = initial.value;
    } else if (initial is DaftarSetFilter) {
      chosen = {...initial.values};
    } else if (initial is DaftarRangeFilter) {
      minText = initial.min?.toString() ?? "";
      maxText = initial.max?.toString() ?? "";
    } else if (initial is DaftarDateFilter) {
      start = initial.start;
      end = initial.end;
    } else if (initial is DaftarBoolFilter) {
      paid = initial.value;
    }
  }

  DaftarFilter? build_() {
    DaftarColumn? c = column;
    if (c == null) return null;
    switch (daftarColumnKind(c)) {
      case DaftarColumnKind.text:
        return DaftarTextFilter(c, mode, text);
      case DaftarColumnKind.set:
        return chosen.isEmpty ? null : DaftarSetFilter(c, chosen);
      case DaftarColumnKind.number:
        double? min = double.tryParse(minText.trim());
        double? max = double.tryParse(maxText.trim());
        if (min == null && max == null) return null;
        return DaftarRangeFilter(c, min: min, max: max);
      case DaftarColumnKind.date:
        if (start == null && end == null) return null;
        return DaftarDateFilter(c, start: start, end: end);
      case DaftarColumnKind.bool:
        return DaftarBoolFilter(c, paid);
    }
  }

  @override
  Widget build(BuildContext context) {
    DaftarColumn? column = this.column;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectChips<DaftarColumn>(
          items: DaftarColumn.values,
          getSelected: (c) => c == column,
          onSelected: (c) => setState(() => this.column = c),
          getLabel: daftarColumnLabel,
          wrapped: true,
        ),
        SizedBox(height: 12),
        if (column != null) _conditionFor(context, column),
        SizedBox(height: 16),
        Button(
          label: "apply".tr(),
          expandedLayout: true,
          disabled: build_() == null,
          onTap: () {
            DaftarFilter? filter = build_();
            if (filter != null) widget.onDone(filter);
          },
        ),
      ],
    );
  }

  Widget _conditionFor(BuildContext context, DaftarColumn column) {
    switch (daftarColumnKind(column)) {
      case DaftarColumnKind.text:
        bool needsText =
            mode != DaftarTextMode.isEmpty && mode != DaftarTextMode.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectChips<DaftarTextMode>(
              items: DaftarTextMode.values,
              getSelected: (m) => m == mode,
              onSelected: (m) => setState(() => mode = m),
              getLabel: (m) => _textModeLabel(m).tr(),
              wrapped: true,
            ),
            if (needsText) ...[
              SizedBox(height: 10),
              TextInput(
                labelText: daftarColumnLabel(column),
                initialValue: text,
                autoFocus: true,
                padding: EdgeInsetsDirectional.zero,
                onChanged: (value) => setState(() => text = value),
              ),
            ],
          ],
        );
      case DaftarColumnKind.set:
        List<MapEntry<String?, String>> values =
            daftarValuesOf(widget.rows, column);
        List<MapEntry<String?, String>> shown = values
            .where((e) =>
                e.value.toLowerCase().contains(valueSearch.toLowerCase()))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (values.length > 8)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: TextInput(
                  labelText: "daftar-search".tr(),
                  icon: Icons.search_rounded,
                  padding: EdgeInsetsDirectional.zero,
                  onChanged: (value) => setState(() => valueSearch = value),
                ),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => chosen.addAll(shown.map((e) => e.key))),
                  child: TextFont(text: "select-all".tr(), fontSize: 14),
                ),
                TextButton(
                  onPressed: () => setState(() => chosen.clear()),
                  child: TextFont(text: "clear".tr(), fontSize: 14),
                ),
              ],
            ),
            for (MapEntry<String?, String> value in shown)
              CheckboxListTile(
                dense: true,
                value: chosen.contains(value.key),
                title: TextFont(text: value.value, fontSize: 15),
                onChanged: (on) => setState(() {
                  if (on == true)
                    chosen.add(value.key);
                  else
                    chosen.remove(value.key);
                }),
              ),
          ],
        );
      case DaftarColumnKind.number:
        return Row(
          children: [
            Expanded(
              child: TextInput(
                labelText: "daftar-min".tr(),
                initialValue: minText,
                keyboardType: TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                padding: EdgeInsetsDirectional.zero,
                onChanged: (value) => setState(() => minText = value),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: TextInput(
                labelText: "daftar-max".tr(),
                initialValue: maxText,
                keyboardType: TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                padding: EdgeInsetsDirectional.zero,
                onChanged: (value) => setState(() => maxText = value),
              ),
            ),
          ],
        );
      case DaftarColumnKind.date:
        DateFormat format = DateFormat.yMMMd(context.locale.toString());
        Widget pick(String label, DateTime? value, Function(DateTime?) set) =>
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? DateTime.now(),
                    firstDate: DateTime(1990),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => set(picked));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: TextFont(
                    text: label +
                        ": " +
                        (value == null ? "…" : format.format(value)),
                    fontSize: 15,
                  ),
                ),
              ),
            );
        return Row(
          children: [
            pick("daftar-from".tr(), start, (d) => start = d),
            SizedBox(width: 10),
            pick("daftar-to".tr(), end, (d) => end = d),
          ],
        );
      case DaftarColumnKind.bool:
        return SelectChips<bool>(
          items: [true, false],
          getSelected: (v) => v == paid,
          onSelected: (v) => setState(() => paid = v),
          getLabel: (v) => (v ? "daftar-yes" : "daftar-no").tr(),
        );
    }
  }
}
