// Daftar: the desktop spreadsheet view of all transactions.
// This file is plain Dart (no database or widgets) so the filtering, sorting,
// search and totals can be unit tested.

enum DaftarColumn {
  date,
  title,
  category,
  subcategory,
  amount,
  account,
  type,
  paid,
  note,
  place,
  paidIn,
}

enum DaftarColumnKind { text, set, number, date, bool }

DaftarColumnKind daftarColumnKind(DaftarColumn column) {
  switch (column) {
    case DaftarColumn.date:
      return DaftarColumnKind.date;
    case DaftarColumn.amount:
      return DaftarColumnKind.number;
    case DaftarColumn.paid:
      return DaftarColumnKind.bool;
    case DaftarColumn.category:
    case DaftarColumn.subcategory:
    case DaftarColumn.account:
    case DaftarColumn.type:
      return DaftarColumnKind.set;
    case DaftarColumn.title:
    case DaftarColumn.note:
    case DaftarColumn.place:
    case DaftarColumn.paidIn:
      return DaftarColumnKind.text;
  }
}

// Transaction types shown in the Type column
enum DaftarType {
  expense,
  income,
  transfer,
  upcoming,
  subscription,
  repetitive,
  lent,
  borrowed,
}

// One transaction as Daftar shows it. Ids are kept for filtering by set
// (category, account...), names for display, search and sorting.
class DaftarRow {
  DaftarRow({
    required this.transactionPk,
    required this.date,
    required this.title,
    required this.categoryPk,
    required this.categoryName,
    required this.subcategoryPk,
    required this.subcategoryName,
    required this.amount,
    required this.walletPk,
    required this.walletName,
    required this.currency,
    required this.decimals,
    required this.type,
    required this.paid,
    required this.note,
    required this.place,
    required this.paidIn,
  });
  final String transactionPk;
  final DateTime date;
  final String title;
  final String? categoryPk;
  final String categoryName;
  final String? subcategoryPk;
  final String subcategoryName;
  final double amount; // signed, in the account's currency
  final String walletPk;
  final String walletName;
  final String? currency;
  final int decimals;
  final DaftarType type;
  final bool paid;
  final String note; // what the user wrote (no hidden tags)
  final String place;
  final String paidIn; // "$20.00" for a foreign spend, else ""

  String textOf(DaftarColumn column) {
    switch (column) {
      case DaftarColumn.date:
        return date.toIso8601String();
      case DaftarColumn.title:
        return title;
      case DaftarColumn.category:
        return categoryName;
      case DaftarColumn.subcategory:
        return subcategoryName;
      case DaftarColumn.amount:
        return amount.toString();
      case DaftarColumn.account:
        return walletName;
      case DaftarColumn.type:
        return type.name;
      case DaftarColumn.paid:
        return paid ? "1" : "0";
      case DaftarColumn.note:
        return note;
      case DaftarColumn.place:
        return place;
      case DaftarColumn.paidIn:
        return paidIn;
    }
  }

  // The value a set filter compares against
  String? keyOf(DaftarColumn column) {
    switch (column) {
      case DaftarColumn.category:
        return categoryPk;
      case DaftarColumn.subcategory:
        return subcategoryPk;
      case DaftarColumn.account:
        return walletPk;
      case DaftarColumn.type:
        return type.name;
      default:
        return textOf(column);
    }
  }
}

// ---- Filters ---------------------------------------------------------------

enum DaftarTextMode { contains, equals, startsWith, isEmpty, isNotEmpty }

abstract class DaftarFilter {
  const DaftarFilter(this.column);
  final DaftarColumn column;
  bool matches(DaftarRow row);
  Map<String, dynamic> toJson();

  static DaftarFilter? fromJson(Map<String, dynamic> json) {
    DaftarColumn? column =
        DaftarColumn.values.where((c) => c.name == json["column"]).firstOrNull;
    if (column == null) return null;
    switch (json["kind"]) {
      case "text":
        return DaftarTextFilter(
          column,
          DaftarTextMode.values
                  .where((m) => m.name == json["mode"])
                  .firstOrNull ??
              DaftarTextMode.contains,
          (json["value"] ?? "").toString(),
        );
      case "set":
        return DaftarSetFilter(column,
            {for (dynamic v in (json["values"] as List? ?? [])) v?.toString()});
      case "range":
        return DaftarRangeFilter(column,
            min: (json["min"] as num?)?.toDouble(),
            max: (json["max"] as num?)?.toDouble());
      case "date":
        return DaftarDateFilter(
          column,
          start: DateTime.tryParse(json["start"]?.toString() ?? ""),
          end: DateTime.tryParse(json["end"]?.toString() ?? ""),
        );
      case "bool":
        return DaftarBoolFilter(column, json["value"] == true);
    }
    return null;
  }
}

class DaftarTextFilter extends DaftarFilter {
  const DaftarTextFilter(super.column, this.mode, this.value);
  final DaftarTextMode mode;
  final String value;

  @override
  bool matches(DaftarRow row) {
    String text = row.textOf(column).trim().toLowerCase();
    String query = value.trim().toLowerCase();
    switch (mode) {
      case DaftarTextMode.contains:
        return text.contains(query);
      case DaftarTextMode.equals:
        return text == query;
      case DaftarTextMode.startsWith:
        return text.startsWith(query);
      case DaftarTextMode.isEmpty:
        return text == "";
      case DaftarTextMode.isNotEmpty:
        return text != "";
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        "kind": "text",
        "column": column.name,
        "mode": mode.name,
        "value": value
      };
}

// Row's key is one of [values] (null = "none", e.g. no subcategory)
class DaftarSetFilter extends DaftarFilter {
  const DaftarSetFilter(super.column, this.values);
  final Set<String?> values;

  @override
  bool matches(DaftarRow row) => values.contains(row.keyOf(column));

  @override
  Map<String, dynamic> toJson() =>
      {"kind": "set", "column": column.name, "values": values.toList()};
}

// Amount between min and max (inclusive, either may be open)
class DaftarRangeFilter extends DaftarFilter {
  const DaftarRangeFilter(super.column, {this.min, this.max});
  final double? min;
  final double? max;

  @override
  bool matches(DaftarRow row) {
    double value = row.amount;
    if (min != null && value < min!) return false;
    if (max != null && value > max!) return false;
    return true;
  }

  @override
  Map<String, dynamic> toJson() =>
      {"kind": "range", "column": column.name, "min": min, "max": max};
}

// Date from start (inclusive) to end (inclusive, whole day)
class DaftarDateFilter extends DaftarFilter {
  const DaftarDateFilter(super.column, {this.start, this.end});
  final DateTime? start;
  final DateTime? end;

  @override
  bool matches(DaftarRow row) {
    if (start != null &&
        row.date.isBefore(DateTime(start!.year, start!.month, start!.day)))
      return false;
    if (end != null &&
        !row.date.isBefore(DateTime(end!.year, end!.month, end!.day + 1)))
      return false;
    return true;
  }

  @override
  Map<String, dynamic> toJson() => {
        "kind": "date",
        "column": column.name,
        "start": start?.toIso8601String(),
        "end": end?.toIso8601String(),
      };
}

class DaftarBoolFilter extends DaftarFilter {
  const DaftarBoolFilter(super.column, this.value);
  final bool value;

  @override
  bool matches(DaftarRow row) => row.paid == value;

  @override
  Map<String, dynamic> toJson() =>
      {"kind": "bool", "column": column.name, "value": value};
}

// ---- Sorting ---------------------------------------------------------------

class DaftarSort {
  const DaftarSort(this.column, {this.ascending = true});
  final DaftarColumn column;
  final bool ascending;

  Map<String, dynamic> toJson() =>
      {"column": column.name, "ascending": ascending};

  static DaftarSort? fromJson(Map<String, dynamic> json) {
    DaftarColumn? column =
        DaftarColumn.values.where((c) => c.name == json["column"]).firstOrNull;
    if (column == null) return null;
    return DaftarSort(column, ascending: json["ascending"] != false);
  }
}

int _compare(DaftarRow a, DaftarRow b, DaftarColumn column) {
  switch (column) {
    case DaftarColumn.date:
      return a.date.compareTo(b.date);
    case DaftarColumn.amount:
      return a.amount.compareTo(b.amount);
    case DaftarColumn.paid:
      return (a.paid ? 1 : 0).compareTo(b.paid ? 1 : 0);
    default:
      String x = a.textOf(column).toLowerCase();
      String y = b.textOf(column).toLowerCase();
      // Empty values last when ascending
      if (x == "" && y != "") return 1;
      if (y == "" && x != "") return -1;
      return x.compareTo(y);
  }
}

// ---- The query: filters + search + sort ------------------------------------

class DaftarQuery {
  const DaftarQuery({
    this.filters = const [],
    this.sorts = const [DaftarSort(DaftarColumn.date, ascending: false)],
    this.search = "",
  });
  final List<DaftarFilter> filters;
  final List<DaftarSort> sorts;
  final String search;

  DaftarQuery copyWith({
    List<DaftarFilter>? filters,
    List<DaftarSort>? sorts,
    String? search,
  }) =>
      DaftarQuery(
        filters: filters ?? this.filters,
        sorts: sorts ?? this.sorts,
        search: search ?? this.search,
      );

  // Click: sort by this column only (toggling the direction if it already
  // was). Shift+click: add it as the next sort, or toggle it in place.
  DaftarQuery withSortBy(DaftarColumn column, {bool addToExisting = false}) {
    int index = sorts.indexWhere((s) => s.column == column);
    if (addToExisting) {
      List<DaftarSort> next = [...sorts];
      if (index == -1)
        next.add(DaftarSort(column));
      else
        next[index] = DaftarSort(column, ascending: !sorts[index].ascending);
      return copyWith(sorts: next);
    }
    bool ascending = index == 0
        ? !sorts[0].ascending
        // Dates and amounts start newest/largest first
        : !(column == DaftarColumn.date || column == DaftarColumn.amount);
    return copyWith(sorts: [DaftarSort(column, ascending: ascending)]);
  }

  bool matchesSearch(DaftarRow row) {
    String query = search.trim().toLowerCase();
    if (query == "") return true;
    return row.title.toLowerCase().contains(query) ||
        row.note.toLowerCase().contains(query) ||
        row.place.toLowerCase().contains(query);
  }

  List<DaftarRow> apply(List<DaftarRow> rows) {
    List<DaftarRow> result = rows
        .where(
            (row) => matchesSearch(row) && filters.every((f) => f.matches(row)))
        .toList();
    if (sorts.isNotEmpty) {
      result.sort((a, b) {
        for (DaftarSort sort in sorts) {
          int c = _compare(a, b, sort.column);
          if (c != 0) return sort.ascending ? c : -c;
        }
        return a.transactionPk.compareTo(b.transactionPk);
      });
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        "filters": [for (DaftarFilter f in filters) f.toJson()],
        "sorts": [for (DaftarSort s in sorts) s.toJson()],
        "search": search,
      };

  static DaftarQuery fromJson(Map<String, dynamic> json) => DaftarQuery(
        filters: [
          for (dynamic f in (json["filters"] as List? ?? []))
            if (f is Map) DaftarFilter.fromJson(Map<String, dynamic>.from(f))
        ].whereType<DaftarFilter>().toList(),
        sorts: [
          for (dynamic s in (json["sorts"] as List? ?? []))
            if (s is Map) DaftarSort.fromJson(Map<String, dynamic>.from(s))
        ].whereType<DaftarSort>().toList(),
        search: (json["search"] ?? "").toString(),
      );
}

// Totals per currency (currency key, or "" when unknown), keeping order of
// first appearance
Map<String, double> daftarTotals(Iterable<DaftarRow> rows) {
  Map<String, double> totals = {};
  for (DaftarRow row in rows) {
    String currency = row.currency ?? "";
    totals[currency] = (totals[currency] ?? 0) + row.amount;
  }
  return totals;
}

// ---- Editing (phase 2) -----------------------------------------------------
// Staged edits: transactionPk → column → new value. A key that is present
// with a null value means "set to none" (e.g. no subcategory).
// Values: date DateTime · title String · category String (pk) ·
// subcategory String? (pk) · amount double (signed) · account String (pk) ·
// paid bool · note String · place String ("" = remove the place).
typedef DaftarEdits = Map<String, Map<DaftarColumn, Object?>>;

DaftarEdits copyDaftarEdits(DaftarEdits edits) => {
      for (MapEntry<String, Map<DaftarColumn, Object?>> e in edits.entries)
        e.key: Map.of(e.value)
    };

int daftarEditCount(DaftarEdits edits) =>
    edits.values.fold(0, (sum, columns) => sum + columns.length);

// Which cells can be edited in the grid. Transfers keep their amount, account
// and category (their paired transaction must change too); the type and the
// paid-in original are changed elsewhere.
bool daftarCanEdit(DaftarRow row, DaftarColumn column) {
  switch (column) {
    case DaftarColumn.date:
    case DaftarColumn.title:
    case DaftarColumn.note:
    case DaftarColumn.place:
      return true;
    case DaftarColumn.category:
    case DaftarColumn.subcategory:
    case DaftarColumn.amount:
    case DaftarColumn.account:
      return row.type != DaftarType.transfer;
    case DaftarColumn.paid:
      return const [
        DaftarType.upcoming,
        DaftarType.subscription,
        DaftarType.repetitive,
        DaftarType.lent,
        DaftarType.borrowed,
      ].contains(row.type);
    case DaftarColumn.type:
    case DaftarColumn.paidIn:
      return false;
  }
}

// Columns Delete can clear, and the value they clear to
bool daftarCanClear(DaftarColumn column) => const [
      DaftarColumn.title,
      DaftarColumn.note,
      DaftarColumn.place,
      DaftarColumn.subcategory,
    ].contains(column);

Object? daftarClearedValue(DaftarColumn column) =>
    column == DaftarColumn.subcategory ? null : "";

// "1,250.50", "-20", "+300" → signed amount. Without a sign the current sign
// is kept (an expense stays an expense). Null when it isn't a number.
double? daftarParseAmount(String input, double current) {
  String text = input.trim().replaceAll(RegExp(r"[^0-9.+\-]"), "");
  if (text == "") return null;
  bool explicitMinus = text.startsWith("-");
  bool explicitPlus = text.startsWith("+");
  double? value = double.tryParse(text.replaceAll(RegExp(r"^[+\-]"), ""));
  if (value == null) return null;
  if (explicitMinus) return -value;
  if (explicitPlus) return value;
  return current > 0 ? value : -value;
}

// The value a cell holds, in the same form as an edit (used for fill-down)
Object? daftarCellValue(DaftarRow row, DaftarColumn column) {
  switch (column) {
    case DaftarColumn.date:
      return row.date;
    case DaftarColumn.title:
      return row.title;
    case DaftarColumn.category:
      return row.categoryPk;
    case DaftarColumn.subcategory:
      return row.subcategoryPk;
    case DaftarColumn.amount:
      return row.amount;
    case DaftarColumn.account:
      return row.walletPk;
    case DaftarColumn.paid:
      return row.paid;
    case DaftarColumn.note:
      return row.note;
    case DaftarColumn.place:
      return row.place;
    case DaftarColumn.type:
    case DaftarColumn.paidIn:
      return null;
  }
}

// Stage [value] for one cell. Setting a value equal to the original removes
// the edit. Changing the category drops a subcategory that doesn't belong to
// it ([subcategoryBelongs] answers that).
DaftarEdits daftarSetCell(
  DaftarEdits edits,
  DaftarRow original,
  DaftarColumn column,
  Object? value, {
  bool Function(String? subcategoryPk, String? categoryPk)? subcategoryBelongs,
}) {
  DaftarEdits next = copyDaftarEdits(edits);
  Map<DaftarColumn, Object?> columns = next[original.transactionPk] ?? {};
  if (value == daftarCellValue(original, column))
    columns.remove(column);
  else
    columns[column] = value;
  if (column == DaftarColumn.category && subcategoryBelongs != null) {
    String? sub = columns.containsKey(DaftarColumn.subcategory)
        ? columns[DaftarColumn.subcategory] as String?
        : original.subcategoryPk;
    if (sub != null && !subcategoryBelongs(sub, value as String?)) {
      if (original.subcategoryPk == null)
        columns.remove(DaftarColumn.subcategory);
      else
        columns[DaftarColumn.subcategory] = null;
    }
  }
  if (columns.isEmpty)
    next.remove(original.transactionPk);
  else
    next[original.transactionPk] = columns;
  return next;
}
