import 'package:budget/ameen/currencyLens.dart';
import 'package:budget/ameen/perCurrency.dart';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/transactionFilters.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:budget/widgets/transactionEntry/incomeAmountArrow.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// The overall spending page in one currency, for this visit only:
// "All ≈ · AED · INR · USD" above the page. One currency limits the page to
// that currency's accounts and shows it in that currency (exact totals);
// "All" converts into the base currency as before, with the summary amounts
// listed per currency when "Totals per Currency" is on.
// When Home's currency view is on a single currency the whole app already
// shows only that currency, so the chips are hidden.

List<String> spendingPageCurrencies() {
  if (activeCurrencyLens != null) return [];
  List<String> currencies = [];
  for (TransactionWallet wallet in allWalletsUnfiltered.list)
    if (wallet.currency != null && !currencies.contains(wallet.currency))
      currencies.add(wallet.currency!);
  return currencies.length < 2 ? [] : currencies;
}

// The page's account filter for a chosen currency (null = every account)
List<String>? walletPksForPageCurrency(String? currency) {
  if (currency == null || activeCurrencyLens != null) return null;
  return [
    for (TransactionWallet wallet in allWalletsUnfiltered.list)
      if (wallet.currency == currency) wallet.walletPk
  ];
}

String _currencySymbol(String currency) => currency == "aed"
    ? String.fromCharCode(0x20C3)
    : (currenciesJSON[currency]?["Symbol"] ?? "").toString();

// The chips, placed above [child] (the page's applied-filter chips)
Widget withSpendingCurrencyChips({
  required bool enabled,
  required String? selected,
  required Function(String?) onSelected,
  required Widget child,
}) {
  List<String> currencies = enabled ? spendingPageCurrencies() : [];
  if (currencies.isEmpty) return child;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(top: 10),
        child: SelectChips<String?>(
          items: [null, ...currencies],
          getSelected: (currency) => currency == selected,
          onSelected: (currency) => onSelected(currency),
          getLabel: (currency) => currency == null
              ? "all".tr() + " ≈"
              : (_currencySymbol(currency) + " " + currency.toUpperCase())
                  .trim(),
        ),
      ),
      child,
    ],
  );
}

// Per-currency totals for a summary amount in "All", or null to keep
// upstream's single converted amount
Stream<List<CurrencyTotal>>? spendingPerCurrencyTotals({
  required AllWallets allWallets,
  required String? pageCurrency,
  required bool? isIncome,
  SearchFilters? searchFilters,
  DateTimeRange? forcedDateTimeRange,
  bool followCustomPeriodCycle = false,
  bool onlyIncomeAndExpense = false,
}) {
  if (pageCurrency != null || !showTotalsPerCurrency()) return null;
  if (allWallets.allContainSameCurrency()) return null;
  return watchTotalsPerCurrency(
    allWallets: allWallets,
    walletPks: searchFilters?.walletPks.isEmpty == false
        ? searchFilters!.walletPks
        : null,
    isIncome: isIncome,
    searchFilters: searchFilters,
    forcedDateTimeRange: forcedDateTimeRange,
    followCustomPeriodCycle: followCustomPeriodCycle,
    onlyIncomeAndExpense: onlyIncomeAndExpense,
  );
}

// The amount at the end of a spending-page row, one line per currency
class PerCurrencyRowValue extends StatelessWidget {
  const PerCurrencyRowValue({
    required this.stream,
    required this.textColor,
    this.absolute = true,
    super.key,
  });
  final Stream<List<CurrencyTotal>> stream;
  final Color textColor;
  final bool absolute;

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    return StreamBuilder<List<CurrencyTotal>>(
      stream: stream,
      builder: (context, snapshot) => CurrencyTotalsText(
        allWallets: allWallets,
        totals: snapshot.data ?? [],
        fontSize: 18,
        textColor: textColor,
        textAlign: TextAlign.end,
        absoluteValue: absolute,
        autoSize: false,
      ),
    );
  }
}

// Transactions tab month banner (expense · income · net) per currency, or null
// to keep upstream's converted banner
Widget? perCurrencyMonthBanner(BuildContext context, DateTimeRange? range) {
  AllWallets allWallets = Provider.of<AllWallets>(context);
  if (!showTotalsPerCurrency() || allWallets.allContainSameCurrency())
    return null;
  Stream<List<CurrencyTotal>> totals(bool isIncome) => watchTotalsPerCurrency(
        allWallets: allWallets,
        walletPks: null,
        isIncome: isIncome,
        forcedDateTimeRange: range,
        onlyIncomeAndExpense: true,
      );
  return StreamBuilder<List<CurrencyTotal>>(
    stream: totals(false),
    builder: (context, expenseSnapshot) => StreamBuilder<List<CurrencyTotal>>(
      stream: totals(true),
      builder: (context, incomeSnapshot) {
        List<CurrencyTotal> expense = _nonZero(expenseSnapshot.data);
        List<CurrencyTotal> income = _nonZero(incomeSnapshot.data);
        List<CurrencyTotal> net = _net(expense, income);
        Widget column(List<CurrencyTotal> list, Color color, Widget? arrow) =>
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (arrow != null) arrow,
                  Flexible(
                    child: CurrencyTotalsText(
                      allWallets: allWallets,
                      totals: list.isEmpty
                          ? [
                              CurrencyTotal(
                                  currency: null, total: 0, decimals: 2)
                            ]
                          : list,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      textColor: color,
                      textAlign: TextAlign.center,
                      absoluteValue: arrow != null,
                    ),
                  ),
                ],
              ),
            );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            column(
                expense,
                getColor(context, "expenseAmount"),
                IncomeOutcomeArrow(
                    color: getColor(context, "expenseAmount"),
                    isIncome: false,
                    iconSize: 20,
                    width: 17)),
            column(
                income,
                getColor(context, "incomeAmount"),
                IncomeOutcomeArrow(
                    color: getColor(context, "incomeAmount"),
                    isIncome: true,
                    iconSize: 20,
                    width: 17)),
            column(net, getColor(context, "black"), null),
          ],
        );
      },
    ),
  );
}

List<CurrencyTotal> _nonZero(List<CurrencyTotal>? totals) =>
    (totals ?? []).where((t) => t.total != 0).toList();

List<CurrencyTotal> _net(
    List<CurrencyTotal> expense, List<CurrencyTotal> income) {
  Map<String?, CurrencyTotal> byCurrency = {};
  for (CurrencyTotal t in [...expense, ...income]) {
    CurrencyTotal? sum = byCurrency[t.currency];
    if (sum == null)
      byCurrency[t.currency] = CurrencyTotal(
          currency: t.currency, total: t.total, decimals: t.decimals);
    else
      sum.total += t.total;
  }
  return byCurrency.values.toList();
}
