import 'package:budget/widgets/openSnackbar.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/ameen/daftar/daftarCellEditors.dart';
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
const double _gutter = 32; // the open-transaction button at the row start
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

  // Editing (phase 2): staged edits with undo/redo, a cell cursor and one
  // cell edited in place (title, amount)
  Map<String, DaftarRow> _byPk = {};
  DaftarColumn _cursorColumn = DaftarColumn.title;
  DaftarEdits _edits = {};
  final List<DaftarEdits> _undo = [];
  final List<DaftarEdits> _redo = [];
  (String, DaftarColumn)? _inline;
  final TextEditingController _inlineController = TextEditingController();
  final FocusNode _inlineFocus = FocusNode();
  bool _saving = false;
  // A dialog editor is open; further edits wait until it closes
  bool _editorOpen = false;

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
    _inlineController.dispose();
    _inlineFocus.dispose();
    super.dispose();
  }

  // ---- data ----------------------------------------------------------------

  void _rebuildRows() {
    AllWallets wallets = Provider.of<AllWallets>(context, listen: false);
    _builtWithWallets = wallets;
    _rows = [
      for (Transaction t in _transactions) daftarRowOf(t, _categories, wallets)
    ];
    _byPk = {for (DaftarRow r in _rows) r.transactionPk: r};
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

  AllWallets get _wallets =>
      _builtWithWallets ?? Provider.of<AllWallets>(context, listen: false);

  // A row as shown: with its staged edits
  DaftarRow _display(DaftarRow row) =>
      daftarRowWithEdits(row, _edits[row.transactionPk], _categories, _wallets);

  void _tapCell(int index, DaftarColumn column) {
    if (_inline != null) {
      if (_inline!.$1 == _shown[index].transactionPk && _inline!.$2 == column)
        return;
      _commitInline();
    }
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
      _cursorColumn = column;
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

  void _scrollToRow(int index) {
    if (!_vertical.hasClients) return;
    double top = index * _rowHeight;
    double viewport = _vertical.position.viewportDimension;
    if (top < _vertical.offset)
      _vertical.jumpTo(top);
    else if (top + _rowHeight > _vertical.offset + viewport)
      _vertical.jumpTo(top + _rowHeight - viewport);
  }

  void _moveCursor(int delta) {
    if (_shown.isEmpty) return;
    int index = ((_cursor ?? -1) + delta).clamp(0, _shown.length - 1);
    setState(() {
      _cursor = index;
      _anchor = index;
      _selected = {_shown[index].transactionPk};
    });
    _scrollToRow(index);
  }

  void _moveColumn(int delta) {
    List<DaftarColumn> columns = _columns;
    int at = columns.indexOf(_cursorColumn);
    int next = (at == -1 ? 0 : at + delta).clamp(0, columns.length - 1);
    setState(() => _cursorColumn = columns[next]);
    // Keep the cursor column in view
    if (!_horizontal.hasClients) return;
    double left = 40;
    for (DaftarColumn c in columns.take(next)) left += _widths[c]!;
    double right = left + _widths[columns[next]]!;
    double view = _horizontal.position.viewportDimension;
    if (left < _horizontal.offset)
      _horizontal.jumpTo(left - 40);
    else if (right > _horizontal.offset + view)
      _horizontal
          .jumpTo(min(right - view, _horizontal.position.maxScrollExtent));
  }

  // ---- staged edits ----------------------------------------------------------

  bool _subcategoryBelongs(String? subcategoryPk, String? categoryPk) =>
      subcategoryPk == null ||
      _categories[subcategoryPk]?.mainCategoryPk == categoryPk;

  void _stage(DaftarEdits next) {
    setState(() {
      _undo.add(_edits);
      if (_undo.length > 100) _undo.removeAt(0);
      _redo.clear();
      _edits = next;
    });
  }

  DaftarEdits _withCell(DaftarEdits edits, DaftarRow original,
          DaftarColumn column, Object? value) =>
      daftarSetCell(edits, original, column, value,
          subcategoryBelongs: _subcategoryBelongs);

  void _setCell(DaftarRow original, DaftarColumn column, Object? value) =>
      _stage(_withCell(_edits, original, column, value));

  void _undoEdit() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add(_edits);
      _edits = _undo.removeLast();
    });
  }

  void _redoEdit() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add(_edits);
      _edits = _redo.removeLast();
    });
  }

  // Discarding can be undone (Ctrl+Z) until the page is left
  void _discard() => _stage({});

  Future _save() async {
    if (_inline != null) _commitInline();
    if (_edits.isEmpty || _saving) return;
    setState(() => _saving = true);
    int transactions = _edits.length;
    DaftarSaveResult result = await saveDaftarEdits(_edits);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _edits = {
        for (String pk in result.failed)
          if (_edits[pk] != null) pk: _edits[pk]!
      };
      _undo.clear();
      _redo.clear();
    });
    openSnackbar(SnackbarMessage(
      title: result.failed.isEmpty
          ? "daftar-saved".tr(namedArgs: {"count": result.saved.toString()})
          : "daftar-save-failed".tr(namedArgs: {
              "failed": result.failed.length.toString(),
              "count": transactions.toString(),
            }),
      icon: result.failed.isEmpty
          ? Icons.check_circle_rounded
          : Icons.warning_rounded,
    ));
    _focus.requestFocus();
  }

  // Edit one cell: in place for title and amount, a dialog for the rest
  Future _editCell(int index, DaftarColumn column, {String? startWith}) async {
    DaftarRow original = _shown[index];
    DaftarRow shown = _display(original);
    if (!daftarCanEdit(shown, column)) return;
    if (_editorOpen) return;
    if (_inline != null) {
      if (_inline == (original.transactionPk, column)) return;
      _commitInline();
    }
    _editorOpen = true;
    try {
      await _editCellNow(original, shown, column, startWith);
    } finally {
      _editorOpen = false;
    }
  }

  Future _editCellNow(DaftarRow original, DaftarRow shown,
      DaftarColumn column, String? startWith) async {
    switch (column) {
      case DaftarColumn.title:
        _startInline(original, column, startWith ?? shown.title,
            startedByTyping: startWith != null);
        return;
      case DaftarColumn.amount:
        _startInline(original, column,
            startWith ?? _plainAmount(shown.amount.abs(), shown.decimals),
            startedByTyping: startWith != null);
        return;
      case DaftarColumn.date:
        DateTime? date = await pickDaftarDate(context, shown.date);
        if (date != null) _setCell(original, column, date);
        break;
      case DaftarColumn.category:
        DaftarChoice<String?>? choice =
            await pickDaftarCategory(context, _categories, shown.categoryPk);
        if (choice != null) _setCell(original, column, choice.value);
        break;
      case DaftarColumn.subcategory:
        DaftarChoice<String?>? choice = await pickDaftarSubcategory(
            context, _categories, shown.categoryPk, shown.subcategoryPk);
        if (choice != null) _setCell(original, column, choice.value);
        break;
      case DaftarColumn.account:
        DaftarChoice<String>? choice = await pickDaftarAccount(
            context, _wallets, shown.walletPk, shown.currency);
        if (choice != null) _setCell(original, column, choice.value);
        break;
      case DaftarColumn.paid:
        _setCell(original, column, !shown.paid);
        break;
      case DaftarColumn.note:
        String? note = await editDaftarNote(context, shown.note);
        if (note != null) _setCell(original, column, note);
        break;
      case DaftarColumn.place:
        String? place = await editDaftarPlace(context, shown.place);
        if (place != null) _setCell(original, column, place.trim());
        break;
      case DaftarColumn.type:
      case DaftarColumn.paidIn:
        return;
    }
    _focus.requestFocus();
  }

  // "6.44" (the account's decimals, no trailing zeros)
  String _plainAmount(double value, int decimals) {
    String text = value.toStringAsFixed(decimals);
    if (text.contains(".")) text = text.replaceAll(RegExp(r"\.?0+$"), "");
    return text;
  }

  void _startInline(DaftarRow original, DaftarColumn column, String text,
      {bool startedByTyping = false}) {
    // Let go of the grid's focus so the editor's autofocus takes the
    // keyboard (as a dialog's text field does)
    _focus.unfocus();
    setState(() {
      _inline = (original.transactionPk, column);
      _inlineController.text = text;
      // Typing replaces the value; a typed first character keeps going
      _inlineController.selection = startedByTyping
          ? TextSelection.collapsed(offset: text.length)
          : TextSelection(baseOffset: 0, extentOffset: text.length);
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _inlineFocus.requestFocus());
  }

  // Applies the text being typed; [then] moves the cursor afterwards
  void _commitInline({void Function()? then}) {
    (String, DaftarColumn)? editing = _inline;
    if (editing == null) return;
    DaftarRow? original = _byPk[editing.$1];
    String text = _inlineController.text;
    setState(() => _inline = null);
    if (original != null) {
      if (editing.$2 == DaftarColumn.title) {
        _setCell(original, DaftarColumn.title, text.trim());
      } else if (editing.$2 == DaftarColumn.amount) {
        double? amount = daftarParseAmount(text, _display(original).amount);
        if (amount != null)
          _setCell(original, DaftarColumn.amount, amount);
        else
          openSnackbar(SnackbarMessage(
              title: "daftar-not-a-number".tr(), icon: Icons.warning_rounded));
      }
    }
    _focus.requestFocus();
    then?.call();
  }

  void _cancelInline() {
    setState(() => _inline = null);
    _focus.requestFocus();
  }

  KeyEventResult _onInlineKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelInline();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      bool back = HardwareKeyboard.instance.isShiftPressed;
      _commitInline(then: () => _moveColumn(back ? -1 : 1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // Ctrl+D: the cursor cell's value into the same column of every selected row
  void _fillDown() {
    if (_cursor == null || _selected.length < 2) return;
    DaftarColumn column = _cursorColumn;
    Object? value = daftarCellValue(_display(_shown[_cursor!]), column);
    DaftarEdits next = _edits;
    for (DaftarRow row in _shown) {
      if (!_selected.contains(row.transactionPk)) continue;
      DaftarRow shown = _display(row);
      if (!daftarCanEdit(shown, column)) continue;
      // Accounts only within the same currency
      if (column == DaftarColumn.account &&
          _wallets.indexedByPk[value]?.currency != shown.currency) continue;
      // Subcategories only within their category
      if (column == DaftarColumn.subcategory &&
          !_subcategoryBelongs(value as String?, shown.categoryPk)) continue;
      next = _withCell(next, row, column, value);
    }
    _stage(next);
  }

  // Delete: clear the cursor column in the selected rows (or the cursor row)
  void _clearCells() {
    DaftarColumn column = _cursorColumn;
    if (!daftarCanClear(column)) return;
    DaftarEdits next = _edits;
    for (DaftarRow row in _shown) {
      bool target = _selected.isEmpty
          ? _cursor != null && row == _shown[_cursor!]
          : _selected.contains(row.transactionPk);
      if (!target || !daftarCanEdit(_display(row), column)) continue;
      next = _withCell(next, row, column, daftarClearedValue(column));
    }
    _stage(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_inline != null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    bool command = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    bool shift = HardwareKeyboard.instance.isShiftPressed;
    LogicalKeyboardKey key = event.logicalKey;
    KeyEventResult done(void Function() action) {
      action();
      return KeyEventResult.handled;
    }

    if (command) {
      if (key == LogicalKeyboardKey.keyA)
        return done(() => setState(
            () => _selected = {for (DaftarRow r in _shown) r.transactionPk}));
      if (key == LogicalKeyboardKey.keyZ)
        return done(shift ? _redoEdit : _undoEdit);
      if (key == LogicalKeyboardKey.keyY) return done(_redoEdit);
      if (key == LogicalKeyboardKey.keyS) return done(_save);
      if (key == LogicalKeyboardKey.keyD) return done(_fillDown);
      if (key == LogicalKeyboardKey.enter && _cursor != null)
        return done(() => _openRow(_cursor!));
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape && _selected.isNotEmpty)
      return done(() => setState(() => _selected = {}));
    if (key == LogicalKeyboardKey.arrowDown) return done(() => _moveCursor(1));
    if (key == LogicalKeyboardKey.arrowUp) return done(() => _moveCursor(-1));
    if (key == LogicalKeyboardKey.arrowRight) return done(() => _moveColumn(1));
    if (key == LogicalKeyboardKey.arrowLeft) return done(() => _moveColumn(-1));
    if (key == LogicalKeyboardKey.tab)
      return done(() => _moveColumn(shift ? -1 : 1));
    if (_cursor == null) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.f2)
      return done(() => _editCell(_cursor!, _cursorColumn));
    if (key == LogicalKeyboardKey.space && _cursorColumn == DaftarColumn.paid)
      return done(() => _editCell(_cursor!, _cursorColumn));
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace)
      return done(_clearCells);
    // Typing starts editing a title or amount, like a spreadsheet
    String? character = event.character;
    if (character != null &&
        character.length == 1 &&
        character.trim() != "" &&
        (_cursorColumn == DaftarColumn.title ||
            _cursorColumn == DaftarColumn.amount))
      return done(
          () => _editCell(_cursor!, _cursorColumn, startWith: character));
    return KeyEventResult.ignored;
  }

  // Leaving with unsaved changes asks first
  Future _leave() async {
    if (_edits.isEmpty) {
      popRoute(context);
      return;
    }
    bool? discard = await showDaftarDialog<bool>(
      context,
      title: "daftar-unsaved".tr(),
      maxWidth: 440,
      builder: (dialogContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFont(
            text: "daftar-unsaved-description".tr(namedArgs: {
              "count": daftarEditCount(_edits).toString(),
            }),
            fontSize: 15,
            maxLines: 4,
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Button(
                  label: "daftar-discard-leave".tr(),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  textColor: Theme.of(context).colorScheme.onTertiaryContainer,
                  expandedLayout: true,
                  onTap: () => Navigator.of(dialogContext).pop(true),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Button(
                  label: "daftar-keep-editing".tr(),
                  expandedLayout: true,
                  onTap: () => Navigator.of(dialogContext).pop(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _edits = {});
      popRoute(context);
    }
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

    return PopScope(
      canPop: _edits.isEmpty,
      onPopInvoked: (didPop) {
        if (!didPop) _leave();
      },
      child: Scaffold(
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
                if (_edits.isNotEmpty) _changesBar(context),
                _footer(context, wallets),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _changesBar(BuildContext context) {
    int cells = daftarEditCount(_edits);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 12, 8),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          Icon(Icons.edit_note_rounded,
              color: Theme.of(context).colorScheme.onSecondaryContainer),
          SizedBox(width: 10),
          TextFont(
            text: (cells == 1 ? "daftar-change-one" : "daftar-changes-many")
                    .tr(namedArgs: {"count": cells.toString()}) +
                " " +
                (_edits.length == 1
                        ? "daftar-in-transaction-one"
                        : "daftar-in-transactions-many")
                    .tr(namedArgs: {"count": _edits.length.toString()}),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(width: 12),
          IconButton(
            tooltip: "daftar-undo".tr(),
            icon: Icon(Icons.undo_rounded),
            onPressed: _undo.isEmpty ? null : _undoEdit,
          ),
          IconButton(
            tooltip: "daftar-redo".tr(),
            icon: Icon(Icons.redo_rounded),
            onPressed: _redo.isEmpty ? null : _redoEdit,
          ),
          Spacer(),
          TextButton(
            onPressed: _saving ? null : _discard,
            child: TextFont(text: "daftar-discard".tr(), fontSize: 15),
          ),
          SizedBox(width: 8),
          Button(
            label: _saving ? "daftar-saving".tr() : "save".tr(),
            icon: Icons.save_rounded,
            onTap: _save,
            disabled: _saving,
          ),
        ],
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
            onPressed: _leave,
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
    double totalWidth =
        columns.fold(0.0, (sum, c) => sum + _widths[c]!) + 16 + _gutter;
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
          SizedBox(width: _gutter),
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
    DaftarRow original = _shown[index];
    DaftarRow row = _display(original);
    Map<DaftarColumn, Object?>? edited = _edits[original.transactionPk];
    bool selected = _selected.contains(original.transactionPk);
    Color? background = selected
        ? Theme.of(context).colorScheme.secondaryContainer
        : index.isOdd
            ? getColor(context, "lightDarkAccent").withOpacity(0.45)
            : null;
    Color editedColor = Colors.amber.withOpacity(0.22);
    Color cursorColor = Theme.of(context).colorScheme.secondary;
    return Container(
      color: background,
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Row(
        children: [
          SizedBox(
            width: _gutter,
            child: IconButton(
              tooltip: "daftar-open".tr(),
              padding: EdgeInsets.zero,
              iconSize: 16,
              icon: Icon(Icons.open_in_new_rounded,
                  color: getColor(context, "textLight").withOpacity(0.7)),
              onPressed: () => _openRow(index),
            ),
          ),
          for (DaftarColumn column in columns)
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _tapCell(index, column),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _editCell(index, column),
                child: Container(
                  width: _widths[column]!,
                  height: _rowHeight,
                  decoration: BoxDecoration(
                    color: edited != null && edited.containsKey(column)
                        ? editedColor
                        : null,
                    border: _cursor == index && _cursorColumn == column
                        ? Border.all(color: cursorColor, width: 1.5)
                        : null,
                  ),
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                  child: _inline?.$1 == original.transactionPk &&
                          _inline?.$2 == column
                      ? _inlineEditor(context, column)
                      : _cell(context, wallets, row, column),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inlineEditor(BuildContext context, DaftarColumn column) {
    return Focus(
      onKeyEvent: _onInlineKey,
      child: Center(
          child: TextField(
        controller: _inlineController,
        focusNode: _inlineFocus,
        autofocus: true,
        textAlign:
            column == DaftarColumn.amount ? TextAlign.end : TextAlign.start,
        keyboardType: column == DaftarColumn.amount
            ? TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        style: TextStyle(
          fontSize: 14,
          color: getColor(context, "black"),
          fontFamily: appStateSettings["font"],
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onSubmitted: (_) => _commitInline(then: () => _moveCursor(1)),
        onTapOutside: (_) => _commitInline(),
      )),
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
        bool editable = daftarCanEdit(row, column);
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: row.paid
              ? Icon(Icons.check_rounded,
                  size: 18,
                  color: editable
                      ? Theme.of(context).colorScheme.secondary
                      : getColor(context, "textLight"))
              : editable
                  ? Icon(Icons.radio_button_unchecked_rounded,
                      size: 16, color: getColor(context, "textLight"))
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
    Iterable<DaftarRow> counted = (_selected.isEmpty
            ? _shown
            : _shown.where((r) => _selected.contains(r.transactionPk)))
        .map(_display);
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
