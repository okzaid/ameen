import 'dart:async';

import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/transactionFilters.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/animatedExpanded.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/ameen/currencyOverrides.dart';
import 'package:budget/colors.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Ameen shows balances per currency (AED 1,200 · USD 300) instead of converting
// everything into one primary currency. The toggle lives in the accounts
// settings, budgets and charts keep using the base (primary) currency.

const String perCurrencyTotalsSetting = "ameenPerCurrencyTotals";

bool showTotalsPerCurrency() => appStateSettings[perCurrencyTotalsSetting] != false;

class CurrencyTotal {
  CurrencyTotal({
    required this.currency,
    required this.total,
    required this.decimals,
    this.count = 0,
  });
  final String? currency;
  double total;
  int decimals;
  int count;
}

// Sums amounts in their own currency, keeping currencies in first-seen order
List<CurrencyTotal> sumPerCurrency<T>(
  Iterable<T> items, {
  required String? Function(T) getCurrency,
  required double Function(T) getAmount,
  int Function(T)? getDecimals,
  int Function(T)? getCount,
}) {
  Map<String?, CurrencyTotal> totals = {};
  for (T item in items) {
    String? currency = getCurrency(item);
    int decimals = getDecimals?.call(item) ?? 2;
    CurrencyTotal total = totals.putIfAbsent(currency,
        () => CurrencyTotal(currency: currency, total: 0, decimals: decimals));
    total.total += getAmount(item);
    total.count += getCount?.call(item) ?? 0;
    if (decimals > total.decimals) total.decimals = decimals;
  }
  return totals.values.toList();
}

List<CurrencyTotal> walletTotalsPerCurrency(
    Iterable<WalletWithDetails> walletsWithDetails) {
  return sumPerCurrency<WalletWithDetails>(
    walletsWithDetails,
    getCurrency: (w) => w.wallet.currency,
    getAmount: (w) => w.totalSpent ?? 0,
    getDecimals: (w) => w.wallet.decimals,
    getCount: (w) => w.numberTransactions ?? 0,
  );
}

double convertedTotal(AllWallets allWallets, List<CurrencyTotal> totals) {
  double sum = 0;
  for (CurrencyTotal total in totals) {
    sum += total.total * amountRatioToPrimaryCurrency(allWallets, total.currency);
  }
  return sum;
}

String formatCurrencyTotal(AllWallets allWallets, CurrencyTotal total,
    {bool addCurrencyName = false}) {
  return convertToMoney(
    allWallets,
    total.total,
    currencyKey: total.currency,
    decimals: total.decimals,
    addCurrencyName: addCurrencyName,
  );
}

// "Đ1,200 · $300", or the converted single total when per-currency is off
String formatTotals(AllWallets allWallets, List<CurrencyTotal> totals,
    {String separator = "  ·  ", bool? perCurrency}) {
  if (totals.isEmpty) return convertToMoney(allWallets, 0);
  if ((perCurrency ?? showTotalsPerCurrency()) == false || totals.length == 1) {
    if (totals.length == 1)
      return formatCurrencyTotal(allWallets, totals.first,
          addCurrencyName: currencyNeedsName(allWallets, totals.first.currency));
    return convertToMoney(allWallets, convertedTotal(allWallets, totals));
  }
  bool addCurrencyName = needsCurrencyName(totals);
  return totals
      .map((total) => formatCurrencyTotal(allWallets, total,
          addCurrencyName: addCurrencyName))
      .join(separator);
}

// Code is added only when the symbol alone is ambiguous: no symbol, or
// another of the user's account currencies uses the same symbol (USD, CAD)
bool currencyNeedsName(AllWallets allWallets, String? currency) {
  currency ??= allWallets.indexedByPk[appStateSettings["selectedWalletPk"]]
      ?.currency;
  String symbol = currenciesJSON[currency]?["Symbol"] ?? "";
  if (symbol == "") return true;
  for (String? other in allWallets.list.map((w) => w.currency).toSet()) {
    if (other != currency && (currenciesJSON[other]?["Symbol"] ?? "") == symbol)
      return true;
  }
  return false;
}

// Currency codes are added when two currencies share a symbol (e.g. USD, CAD)
bool needsCurrencyName(List<CurrencyTotal> totals) {
  Set<String> symbols = {};
  for (CurrencyTotal total in totals) {
    String symbol = currenciesJSON[total.currency]?["Symbol"] ?? "";
    if (symbol == "" || symbols.contains(symbol)) return true;
    symbols.add(symbol);
  }
  return false;
}

// One total per currency for the given wallets, following the same period and
// filters as upstream's watchTotalWithCountOfWallet
Stream<List<CurrencyTotal>> watchTotalsPerCurrency({
  required AllWallets allWallets,
  required List<String>? walletPks,
  bool? isIncome,
  bool followCustomPeriodCycle = false,
  String? cycleSettingsExtension,
  SearchFilters? searchFilters,
  bool includeBalanceCorrection = false,
  bool onlyIncomeAndExpense = false,
}) {
  List<TransactionWallet> wallets = walletPks == null || walletPks.isEmpty
      ? allWallets.list
      : allWallets.list
          .where((wallet) => walletPks.contains(wallet.walletPk))
          .toList();
  Map<String?, List<TransactionWallet>> walletsByCurrency = {};
  for (TransactionWallet wallet in wallets) {
    walletsByCurrency.putIfAbsent(wallet.currency, () => []).add(wallet);
  }
  List<String?> currencies = walletsByCurrency.keys.toList();
  if (currencies.isEmpty) return Stream.value([]);

  List<Stream<TotalWithCount?>> streams = [
    for (String? currency in currencies)
      database.watchTotalWithCountOfWallet(
        isIncome: isIncome,
        // Only query this currency's wallets
        allWallets: AllWallets(
          list: walletsByCurrency[currency]!,
          indexedByPk: allWallets.indexedByPk,
        ),
        followCustomPeriodCycle: followCustomPeriodCycle,
        cycleSettingsExtension: cycleSettingsExtension ?? "",
        includeBalanceCorrection: includeBalanceCorrection,
        onlyIncomeAndExpense: onlyIncomeAndExpense,
        convertToPrimary: false,
        searchFilters: searchFilters,
      )
  ];

  List<TotalWithCount?> latest = List.filled(streams.length, null);
  List<bool> received = List.filled(streams.length, false);
  late StreamController<List<CurrencyTotal>> controller;
  List<StreamSubscription> subscriptions = [];
  controller = StreamController<List<CurrencyTotal>>(
    onListen: () {
      for (int i = 0; i < streams.length; i++) {
        subscriptions.add(streams[i].listen((value) {
          latest[i] = value;
          received[i] = true;
          if (received.every((r) => r)) {
            controller.add([
              for (int j = 0; j < currencies.length; j++)
                CurrencyTotal(
                  currency: currencies[j],
                  total: latest[j]?.total ?? 0,
                  count: latest[j]?.count ?? 0,
                  decimals: walletsByCurrency[currencies[j]]!
                      .map((wallet) => wallet.decimals)
                      .reduce((a, b) => a > b ? a : b),
                )
            ]);
          }
        }, onError: controller.addError));
      }
    },
    onCancel: () {
      for (StreamSubscription subscription in subscriptions) {
        subscription.cancel();
      }
    },
  );
  return controller.stream;
}

// Per-currency amounts stacked one per line, used where upstream shows a
// single converted amount
class CurrencyTotalsText extends StatelessWidget {
  const CurrencyTotalsText({
    required this.allWallets,
    required this.totals,
    this.fontSize = 20,
    this.fontWeight = FontWeight.bold,
    this.textColor,
    this.textAlign = TextAlign.start,
    this.absoluteValue = false,
    this.autoSize = true,
    super.key,
  });
  final bool autoSize;
  final AllWallets allWallets;
  final List<CurrencyTotal> totals;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? textColor;
  final TextAlign textAlign;
  final bool absoluteValue;

  @override
  Widget build(BuildContext context) {
    bool addCurrencyName = needsCurrencyName(totals);
    CrossAxisAlignment alignment = textAlign == TextAlign.center
        ? CrossAxisAlignment.center
        : textAlign == TextAlign.end
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (CurrencyTotal total in totals)
          TextFont(
            text: formatCurrencyTotal(
              allWallets,
              absoluteValue
                  ? CurrencyTotal(
                      currency: total.currency,
                      total: total.total.abs(),
                      decimals: total.decimals)
                  : total,
              addCurrencyName: addCurrencyName,
            ),
            fontSize: fontSize,
            fontWeight: fontWeight,
            textColor: textColor,
            textAlign: textAlign,
            maxLines: 1,
            autoSizeText: autoSize,
            minFontSize: autoSize ? fontSize * 0.5 : null,
          ),
      ],
    );
  }
}

// Amount + transaction count inside upstream's TransactionsAmountBox when it is
// given a per-currency stream
class PerCurrencyAmountBoxValue extends StatelessWidget {
  const PerCurrencyAmountBoxValue({
    required this.stream,
    required this.textColor,
    this.absolute = true,
    this.invertSign = false,
    this.getTextColor,
    super.key,
  });
  final Stream<List<CurrencyTotal>> stream;
  final Color textColor;
  final bool absolute;
  final bool invertSign;
  final Function(double)? getTextColor;

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    return StreamBuilder<List<CurrencyTotal>>(
      stream: stream,
      builder: (context, snapshot) {
        List<CurrencyTotal> totals = snapshot.data ?? [];
        int totalCount = totals.fold(0, (sum, total) => sum + total.count);
        bool addCurrencyName = needsCurrencyName(totals);
        return Column(
          children: [
            if (totals.isEmpty)
              TextFont(
                text: convertToMoney(allWallets, 0),
                textColor: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            for (CurrencyTotal total in totals)
              TextFont(
                text: formatCurrencyTotal(
                  allWallets,
                  CurrencyTotal(
                    currency: total.currency,
                    decimals: total.decimals,
                    total: absolute
                        ? total.total.abs()
                        : total.total * (invertSign ? -1 : 1),
                  ),
                  addCurrencyName: addCurrencyName,
                ),
                textColor: getTextColor != null
                    ? getTextColor!(total.total)
                    : textColor,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
                autoSizeText: true,
                fontSize: 21,
                maxFontSize: 21,
                minFontSize: 10,
                maxLines: 1,
              ),
            SizedBox(height: 6),
            TextFont(
              maxLines: 2,
              text: totalCount.toString() +
                  " " +
                  (totalCount == 1
                      ? "transaction".tr().toLowerCase()
                      : "transactions".tr().toLowerCase()),
              fontSize: 13,
              textAlign: TextAlign.center,
              textColor: getColor(context, "textLight"),
            ),
          ],
        );
      },
    );
  }
}

// Text for the Android net worth home screen widget
Future<String> homeWidgetNetWorthText(AllWallets allWallets,
    List<String>? walletPks, String convertedNetWorth) async {
  String text = convertedNetWorth;
  if (showTotalsPerCurrency()) {
    List<CurrencyTotal> totals = await watchTotalsPerCurrency(
      allWallets: allWallets,
      walletPks: walletPks,
      followCustomPeriodCycle: true,
      cycleSettingsExtension: "NetWorth",
    ).first;
    if (totals.length > 1) text = formatTotals(allWallets, totals);
  }
  return replaceSymbolsForNativeText(text);
}

class PerCurrencyTotalsSettingToggle extends StatelessWidget {
  const PerCurrencyTotalsSettingToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedExpanded(
      expand:
          Provider.of<AllWallets>(context).allContainSameCurrency() == false,
      child: SettingsContainerSwitch(
        title: "totals-per-currency".tr(),
        description: "totals-per-currency-description".tr(),
        onSwitched: (value) {
          updateSettings(perCurrencyTotalsSetting, value,
              updateGlobalState: true);
        },
        initialValue: showTotalsPerCurrency(),
        icon: appStateSettings["outlinedIcons"]
            ? Icons.currency_exchange_outlined
            : Icons.currency_exchange_rounded,
      ),
    );
  }
}
