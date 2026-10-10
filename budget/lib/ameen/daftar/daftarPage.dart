import 'package:budget/widgets/button.dart';
import 'package:budget/ameen/daftar/daftarDialog.dart';
import 'dart:async';
import 'dart:math';

import 'package:budget/ameen/daftar/daftarData.dart';
import 'package:budget/ameen/daftar/daftarFilterEditor.dart';
import 'package:budget/ameen/daftar/daftarModel.dart';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide TextInput;
import 'dart:ui' as ui;
import 'package:provider/provider.dart';

// Daftar (phase 1): every transaction in a grid, with search, filters on any
// column, multi-column sort, saved views, selection and totals. Read-only:
// double-click (or Enter) opens a transaction in the normal editor.
// Link: /daftar (web). Shown on wide screens only.

const double daftarMinWidth = 900;
const double _rowHeight = 38;
const String _layoutSetting = "ameenDaftarLayout";
const String _viewsSetting = "ameenDaftarViews";

const Map<DaftarColumn, double> _defaultWidths = {
  DaftarColumn.date: 160,
  DaftarColumn.title: 220,
  DaftarColumn.category: 170,
  DaftarColumn.subcategory: 150,
  DaftarColumn.amount: 140,
  DaftarColumn.account: 150,
  DaftarColumn.type: 120,
  DaftarColumn.paid: 70,
  DaftarColumn.note: 260,
  DaftarColumn.place: 170,
  DaftarColumn.paidIn: 110,
};

String daftarColumnLabel(DaftarColumn column) {
  switch (column) {
    case DaftarColumn.date:
      return "date".tr();
    case DaftarColumn.title:
      return "title".tr();
    case DaftarColumn.category:
      return "category".tr().capitalizeFirst;
    case DaftarColumn.subcategory:
      return "subcategory".tr();
    case DaftarColumn.amount:
      return "amount".tr();
    case DaftarColumn.account:
      return "account".tr();
    case DaftarColumn.type:
      return "daftar-type".tr();
    case DaftarColumn.paid:
      return "paid".tr();
    case DaftarColumn.note:
      return "note".tr();
    case DaftarColumn.place:
      return "daftar-place".tr();
    case DaftarColumn.paidIn:
      return "paid-in".tr();
  }
}

String daftarTypeLabel(DaftarType type) => type.name.tr();

// Opens Daftar, or explains it needs a wider screen
void openDaftar(BuildContext context) {
  if (MediaQuery.sizeOf(context).width < daftarMinWidth) {
    openPopup(
      context,
      icon: Icons.table_chart_rounded,
      title: "daftar".tr(),
      description: "daftar-wide-screen".tr(),
      onSubmit: () => popRoute(context),
      onSubmitLabel: "ok".tr(),
    );
    return;
  }
  pushRoute(context, DaftarPage());
}

// "Daftar" tile on the More page (wide screens only)
class DaftarMoreEntry extends StatelessWidget {
  const DaftarMoreEntry({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < daftarMinWidth)
      return SizedBox.shrink();
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(vertical: 5, horizontal: 4),
      child: Tappable(
        onTap: () => openDaftar(context),
        borderRadius: 15,
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: getColor(context, "lightDarkAccentHeavy"), width: 2),
          ),
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.table_chart_rounded,
                  color: Theme.of(context).colorScheme.secondary),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFont(
                        text: "daftar".tr(),
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    TextFont(
                      text: "daftar-description".tr(),
                      fontSize: 13,
                      maxLines: 2,
                      textColor: getColor(context, "textLight"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DaftarPage extends StatefulWidget {
  const DaftarPage({super.key});

  @override
  State<DaftarPage> createState() => _DaftarPageState();
}

class _DaftarPageState extends State<DaftarPage> {
  StreamSubscription? _subscription;
  List<Transaction> _transactions = [];
  Map<String, TransactionCategory> _categories = {};
  List<DaftarRow> _rows = [];
  List<DaftarRow> _shown = [];
  bool _loaded = false;
  AllWallets? _builtWithWallets;

  DaftarQuery _query = DaftarQuery();
  Set<String> _selected = {};
  int? _anchor; // index in _shown where a shift-selection starts
  int? _cursor; // index in _shown moved by the arrow keys

  List<DaftarColumn> _hidden = [];
  Map<DaftarColumn, double> _widths = Map.of(_defaultWidths);

  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();
  final FocusNode _focus = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLayout();
    _subscription = watchDaftarSource().listen((source) {
      _transactions = source.$1;
      _categories = source.$2;
      _rebuildRows();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _vertical.dispose();
    _horizontal.dispose();
    _focus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---- data ----------------------------------------------------------------

  void _rebuildRows() {
    AllWallets wallets = Provider.of<AllWallets>(context, listen: false);
    _builtWithWallets = wallets;
    _rows = [
      for (Transaction t in _transactions) daftarRowOf(t, _categories, wallets)
    ];
    _loaded = true;
    _applyQuery();
  }

  void _applyQuery() {
    _shown = _query.apply(_rows);
    Set<String> visible = {for (DaftarRow r in _shown) r.transactionPk};
    _selected = _selected.where(visible.contains).toSet();
    if (_cursor != null && _cursor! >= _shown.length) _cursor = null;
    if (mounted) setState(() {});
  }

  void _setQuery(DaftarQuery query) {
    _query = query;
    _anchor = null;
    _applyQuery();
  }

  // ---- layout and views (settings) -----------------------------------------

  List<DaftarColumn> get _columns =>
      DaftarColumn.values.where((c) => !_hidden.contains(c)).toList();

  void _loadLayout() {
    dynamic layout = appStateSettings[_layoutSetting];
    if (layout is! Map) return;
    _hidden = [
      for (dynamic name in (layout["hidden"] as List? ?? []))
        ...DaftarColumn.values.where((c) => c.name == name)
    ];
    dynamic widths = layout["widths"];
    if (widths is Map)
      for (DaftarColumn c in DaftarColumn.values) {
        dynamic w = widths[c.name];
        if (w is num) _widths[c] = w.toDouble().clamp(60, 600);
      }
  }

  void _saveLayout() {
    updateSettings(
      _layoutSetting,
      {
        "hidden": [for (DaftarColumn c in _hidden) c.name],
        "widths": {for (MapEntry e in _widths.entries) e.key.name: e.value},
      },
      updateGlobalState: false,
    );
  }

  List<Map<String, dynamic>> get _views {
    dynamic stored = appStateSettings[_viewsSetting];
    if (stored is! List) return [];
    return [
      for (dynamic v in stored)
        if (v is Map) Map<String, dynamic>.from(v)
    ];
  }

  Future _saveView() async {
    String typed = "";
    String? name = await showDaftarDialog<String>(
      context,
      title: "daftar-save-view".tr(),
      maxWidth: 420,
      builder: (dialogContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextInput(
            labelText: "daftar-view-name".tr(),
            autoFocus: true,
            padding: EdgeInsetsDirectional.zero,
            onChanged: (value) => typed = value,
            onSubmitted: (_) => Navigator.of(dialogContext).pop(typed),
          ),
          SizedBox(height: 14),
          Button(
            label: "save".tr(),
            expandedLayout: true,
            onTap: () => Navigator.of(dialogContext).pop(typed),
          ),
        ],
      ),
    );
    if (name == null || name.trim() == "") return;
    List<Map<String, dynamic>> views = _views
        .where((v) => v["name"] != name.trim())
        .toList()
      ..add({"name": name.trim(), "query": _query.toJson()});
    await updateSettings(_viewsSetting, views, updateGlobalState: false);
    setState(() {});
  }

  Future _deleteView(String name) async {
    await updateSettings(
        _viewsSetting, _views.where((v) => v["name"] != name).toList(),
        updateGlobalState: false);
    setState(() {});
  }

  // ---- selection and keyboard ----------------------------------------------

  void _tapRow(int index) {
    _focus.requestFocus();
    String pk = _shown[index].transactionPk;
    bool add = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    bool range = HardwareKeyboard.instance.isShiftPressed;
    setState(() {
      if (range && _anchor != null) {
        int from = min(_anchor!, index), to = max(_anchor!, index);
        if (!add) _selected = {};
        for (int i = from; i <= to; i++) _selected.add(_shown[i].transactionPk);
      } else if (add) {
        if (!_selected.remove(pk)) _selected.add(pk);
        _anchor = index;
      } else {
        _selected = {pk};
        _anchor = index;
      }
      _cursor = index;
    });
  }

  Future _openRow(int index) async {
    Transaction? transaction =
        await daftarTransaction(_shown[index].transactionPk);
    if (transaction == null || !mounted) return;
    await pushRoute(
      context,
      AddTransactionPage(
        transaction: transaction,
        routesToPopAfterDelete: RoutesToPopAfterDelete.One,
      ),
    );
    _focus.requestFocus();
  }

  void _moveCursor(int delta) {
    if (_shown.isEmpty) return;
    int index = ((_cursor ?? -1) + delta).clamp(0, _shown.length - 1);
    setState(() {
      _cursor = index;
      _anchor = index;
      _selected = {_shown[index].transactionPk};
    });
    double top = index * _rowHeight;
    double viewport = _vertical.position.viewportDimension;
    if (top < _vertical.offset)
      _vertical.jumpTo(top);
    else if (top + _rowHeight > _vertical.offset + viewport)
      _vertical.jumpTo(top + _rowHeight - viewport);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    bool command = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    LogicalKeyboardKey key = event.logicalKey;
    if (command && key == LogicalKeyboardKey.keyA) {
      setState(() => _selected = {for (DaftarRow r in _shown) r.transactionPk});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _selected.isNotEmpty) {
      setState(() => _selected = {});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveCursor(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveCursor(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && _cursor != null) {
      _openRow(_cursor!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- filters --------------------------------------------------------------

  Future _editFilter({DaftarColumn? column, int? replaceIndex}) async {
    DaftarFilter? initial =
        replaceIndex == null ? null : _query.filters[replaceIndex];
    DaftarFilter? filter = await openDaftarFilterEditor(
      context,
      rows: _rows,
      column: column ?? initial?.column,
      initial: initial,
    );
    if (filter == null) return;
    List<DaftarFilter> filters = [..._query.filters];
    if (replaceIndex != null)
      filters[replaceIndex] = filter;
    else
      filters.add(filter);
    _setQuery(_query.copyWith(filters: filters));
  }

  void _removeFilter(int index) {
    List<DaftarFilter> filters = [..._query.filters]..removeAt(index);
    _setQuery(_query.copyWith(filters: filters));
  }

  void _openColumns() {
    showDaftarDialog(
      context,
      title: "daftar-columns".tr(),
      maxWidth: 420,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          children: [
            for (DaftarColumn column in DaftarColumn.values)
              CheckboxListTile(
                value: !_hidden.contains(column),
                title: TextFont(text: daftarColumnLabel(column)),
                onChanged: (show) {
                  setState(() {
                    if (show == true)
                      _hidden.remove(column);
                    else if (_columns.length > 1) _hidden.add(column);
                  });
                  setSheetState(() {});
                  _saveLayout();
                },
              ),
            TextButton(
              onPressed: () {
                setState(() {
                  _hidden = [];
                  _widths = Map.of(_defaultWidths);
                });
                setSheetState(() {});
                _saveLayout();
              },
              child: TextFont(text: "reset".tr()),
            ),
          ],
        ),
      ),
    );
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Account names and currencies follow the accounts
    AllWallets wallets = Provider.of<AllWallets>(context);
    if (_loaded && !identical(wallets, _builtWithWallets))
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildRows());

    if (MediaQuery.sizeOf(context).width < daftarMinWidth)
      return Scaffold(
        appBar: AppBar(title: TextFont(text: "daftar".tr(), fontSize: 20)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: TextFont(
              text: "daftar-wide-screen".tr(),
              maxLines: 4,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(context),
              _filterBar(context),
              Expanded(child: _grid(context, wallets)),
              _footer(context, wallets),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded),
            onPressed: () => popRoute(context),
          ),
          SizedBox(width: 4),
          Icon(Icons.table_chart_rounded,
              color: Theme.of(context).colorScheme.secondary),
          SizedBox(width: 10),
          TextFont(
              text: "daftar".tr(), fontSize: 24, fontWeight: FontWeight.bold),
          SizedBox(width: 24),
          Expanded(
            child: TextInput(
              labelText: "daftar-search".tr(),
              icon: Icons.search_rounded,
              controller: _searchController,
              padding: EdgeInsetsDirectional.zero,
              onChanged: (text) => _setQuery(_query.copyWith(search: text)),
            ),
          ),
          SizedBox(width: 12),
          _ToolbarButton(
            icon: Icons.filter_list_rounded,
            label: "daftar-add-filter".tr(),
            onTap: () => _editFilter(),
          ),
          _ToolbarButton(
            icon: Icons.view_column_rounded,
            label: "daftar-columns".tr(),
            onTap: _openColumns,
          ),
          _ToolbarButton(
            icon: Icons.bookmark_add_rounded,
            label: "daftar-save-view".tr(),
            onTap: _saveView,
          ),
        ],
      ),
    );
  }

  Widget _filterBar(BuildContext context) {
    List<Map<String, dynamic>> views = _views;
    if (_query.filters.isEmpty && views.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (Map<String, dynamic> view in views)
            InputChip(
              avatar: Icon(Icons.bookmark_rounded, size: 18),
              label: TextFont(text: view["name"].toString(), fontSize: 14),
              onPressed: () {
                DaftarQuery query = DaftarQuery.fromJson(
                    Map<String, dynamic>.from(view["query"] ?? {}));
                _searchController.text = query.search;
                _setQuery(query);
              },
              onDeleted: () => _deleteView(view["name"].toString()),
            ),
          if (views.isNotEmpty && _query.filters.isNotEmpty) SizedBox(width: 8),
          for (int i = 0; i < _query.filters.length; i++)
            InputChip(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              label: TextFont(
                text: describeDaftarFilter(_query.filters[i], _rows),
                fontSize: 14,
              ),
              onPressed: () => _editFilter(replaceIndex: i),
              onDeleted: () => _removeFilter(i),
            ),
          if (_query.filters.length > 1)
            TextButton(
              onPressed: () => _setQuery(_query.copyWith(filters: [])),
              child: TextFont(text: "clear".tr(), fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, AllWallets wallets) {
    List<DaftarColumn> columns = _columns;
    double totalWidth = columns.fold(0.0, (sum, c) => sum + _widths[c]!) + 16;
    if (!_loaded) return Center(child: CircularProgressIndicator());
    return Scrollbar(
      controller: _horizontal,
      thumbVisibility: true,
      notificationPredicate: (n) => n.depth == 0,
      child: SingleChildScrollView(
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: max(totalWidth, MediaQuery.sizeOf(context).width),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, columns),
              Expanded(
                child: _shown.isEmpty
                    ? Center(
                        child: TextFont(
                          text: "daftar-no-results".tr(),
                          textColor: getColor(context, "textLight"),
                        ),
                      )
                    : Scrollbar(
                        controller: _vertical,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _vertical,
                          itemExtent: _rowHeight,
                          itemCount: _shown.length,
                          itemBuilder: (context, index) =>
                              _row(context, wallets, columns, index),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, List<DaftarColumn> columns) {
    return Container(
      height: 42,
      padding: const EdgeInsetsDirectional.only(start: 8),
      decoration: BoxDecoration(
        color: getColor(context, "lightDarkAccent"),
        border: Border(
            bottom: BorderSide(
                color: getColor(context, "lightDarkAccentHeavy"), width: 1)),
      ),
      child: Row(
        children: [
          for (DaftarColumn column in columns)
            _HeaderCell(
              width: _widths[column]!,
              label: daftarColumnLabel(column),
              sortIndex: _query.sorts.indexWhere((s) => s.column == column),
              sortCount: _query.sorts.length,
              ascending: _query.sorts
                      .where((s) => s.column == column)
                      .firstOrNull
                      ?.ascending ??
                  true,
              filtered: _query.filters.any((f) => f.column == column),
              alignEnd: column == DaftarColumn.amount,
              onSort: () => _setQuery(_query.withSortBy(column,
                  addToExisting: HardwareKeyboard.instance.isShiftPressed)),
              onFilter: () => _editFilter(column: column),
              onResize: (delta) => setState(() =>
                  _widths[column] = (_widths[column]! + delta).clamp(60, 600)),
              onResizeEnd: _saveLayout,
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AllWallets wallets,
      List<DaftarColumn> columns, int index) {
    DaftarRow row = _shown[index];
    bool selected = _selected.contains(row.transactionPk);
    Color? background = selected
        ? Theme.of(context).colorScheme.secondaryContainer
        : index.isOdd
            ? getColor(context, "lightDarkAccent").withOpacity(0.45)
            : null;
    return Listener(
      onPointerDown: (_) => _tapRow(index),
      child: GestureDetector(
        onDoubleTap: () => _openRow(index),
        child: Container(
          color: background,
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: Row(
            children: [
              for (DaftarColumn column in columns)
                SizedBox(
                  width: _widths[column]!,
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.symmetric(horizontal: 8),
                    child: _cell(context, wallets, row, column),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, AllWallets wallets, DaftarRow row,
      DaftarColumn column) {
    switch (column) {
      case DaftarColumn.date:
        return _text(
            context,
            DateFormat.yMMMd(context.locale.toString())
                .add_Hm()
                .format(row.date));
      case DaftarColumn.category:
        TransactionCategory? category = _categories[row.categoryPk];
        return Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HexColor(category?.colour,
                    defaultColor: Theme.of(context).colorScheme.primary),
              ),
            ),
            SizedBox(width: 8),
            Expanded(child: _text(context, row.categoryName)),
          ],
        );
      case DaftarColumn.amount:
        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextFont(
            text: convertToMoney(wallets, row.amount,
                currencyKey: row.currency, decimals: row.decimals),
            fontSize: 14,
            maxLines: 1,
            textColor: row.amount < 0
                ? getColor(context, "expenseAmount")
                : row.amount > 0
                    ? getColor(context, "incomeAmount")
                    : null,
          ),
        );
      case DaftarColumn.type:
        return _text(context, daftarTypeLabel(row.type));
      case DaftarColumn.paid:
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: row.paid
              ? Icon(Icons.check_rounded,
                  size: 18, color: getColor(context, "textLight"))
              : SizedBox.shrink(),
        );
      case DaftarColumn.note:
        return _text(context, row.note.replaceAll("\n", " · "));
      default:
        return _text(context, row.textOf(column));
    }
  }

  Widget _text(BuildContext context, String text) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextFont(text: text, fontSize: 14, maxLines: 1),
      );

  Widget _footer(BuildContext context, AllWallets wallets) {
    Iterable<DaftarRow> counted = _selected.isEmpty
        ? _shown
        : _shown.where((r) => _selected.contains(r.transactionPk));
    Map<String, double> totals = daftarTotals(counted);
    String totalsText = totals.entries
        .map((e) => convertToMoney(wallets, e.value,
            currencyKey: e.key == "" ? null : e.key))
        .join("  ·  ");
    return Container(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: getColor(context, "lightDarkAccent"),
        border: Border(
            top: BorderSide(
                color: getColor(context, "lightDarkAccentHeavy"), width: 1)),
      ),
      child: Row(
        children: [
          TextFont(
            text: "daftar-rows".tr(namedArgs: {
                  "shown": _shown.length.toString(),
                  "total": _rows.length.toString(),
                }) +
                (_selected.isEmpty
                    ? ""
                    : "  ·  " +
                        "daftar-selected".tr(
                            namedArgs: {"count": _selected.length.toString()})),
            fontSize: 14,
          ),
          Spacer(),
          TextFont(
            text: (_selected.isEmpty
                    ? "daftar-total".tr()
                    : "daftar-selected-total".tr()) +
                "  " +
                totalsText,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Tappable(
        onTap: onTap,
        borderRadius: 12,
        color: getColor(context, "lightDarkAccent"),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              SizedBox(width: 6),
              TextFont(text: label, fontSize: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.width,
    required this.label,
    required this.sortIndex,
    required this.sortCount,
    required this.ascending,
    required this.filtered,
    required this.alignEnd,
    required this.onSort,
    required this.onFilter,
    required this.onResize,
    required this.onResizeEnd,
  });
  final double width;
  final String label;
  final int sortIndex; // -1 when not sorted by this column
  final int sortCount;
  final bool ascending;
  final bool filtered;
  final bool alignEnd;
  final VoidCallback onSort;
  final VoidCallback onFilter;
  final Function(double delta) onResize;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    Color iconColor = getColor(context, "textLight");
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: onSort,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, end: 10),
                child: Row(
                  mainAxisAlignment: alignEnd
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: TextFont(
                        text: label,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        maxLines: 1,
                      ),
                    ),
                    if (sortIndex != -1) ...[
                      Icon(
                        ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 15,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      if (sortCount > 1)
                        TextFont(
                          text: (sortIndex + 1).toString(),
                          fontSize: 11,
                          textColor: Theme.of(context).colorScheme.secondary,
                        ),
                    ],
                    InkWell(
                      onTap: onFilter,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          filtered
                              ? Icons.filter_alt_rounded
                              : Icons.filter_alt_outlined,
                          size: 19,
                          color: filtered
                              ? Theme.of(context).colorScheme.secondary
                              : iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Drag the right edge to resize
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) => onResize(
                    Directionality.of(context) == ui.TextDirection.rtl
                        ? -d.delta.dx
                        : d.delta.dx),
                onHorizontalDragEnd: (_) => onResizeEnd(),
                child: Container(
                  width: 8,
                  alignment: AlignmentDirectional.center,
                  child: Container(
                    width: 1,
                    height: 20,
                    color: getColor(context, "lightDarkAccentHeavy"),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
