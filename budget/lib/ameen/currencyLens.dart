import 'package:budget/ameen/baseCurrency.dart';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/restartApp.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:drift/drift.dart' show Expression, Constant;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Currency view: show the whole app in one currency. With "INR" chosen, the
// app-wide account list (Provider<AllWallets>.list) only holds INR accounts and
// every transaction query is limited to them, so totals, budgets, charts and
// lists are exact INR sums with no conversion. "All" is upstream's behaviour.
// The lookup index (indexedByPk) always keeps every account.

const String currencyLensSetting = "ameenCurrencyLens";

// Set from the account list; null = All
String? activeCurrencyLens;
Set<String>? lensWalletPks;
AllWallets allWalletsUnfiltered = AllWallets(list: [], indexedByPk: {});

AllWallets applyCurrencyLens(AllWallets all) {
  allWalletsUnfiltered = all;
  dynamic chosen = appStateSettings[currencyLensSetting];
  List<TransactionWallet> inLens = chosen is String && chosen != ""
      ? all.list.where((w) => w.currency == chosen).toList()
      : [];
  // A currency without accounts (all deleted) falls back to All
  if (inLens.isEmpty) {
    activeCurrencyLens = null;
    lensWalletPks = null;
    return all;
  }
  activeCurrencyLens = chosen;
  lensWalletPks = inLens.map((w) => w.walletPk).toSet();
  return AllWallets(list: inLens, indexedByPk: all.indexedByPk);
}

// Startup, before any query is built
Future initCurrencyLens() async {
  List<TransactionWallet> wallets = await database.getAllWallets();
  applyCurrencyLens(AllWallets(
    list: wallets,
    indexedByPk: {for (TransactionWallet w in wallets) w.walletPk: w},
  ));
}

// Added to the shared transaction filters
Expression<bool> currencyLensFilter($TransactionsTable tbl) {
  Set<String>? pks = lensWalletPks;
  if (pks == null) return Constant(true);
  return tbl.walletFk.isIn(pks);
}

// Home's account cards and currency breakdown
Expression<bool> currencyLensWalletFilter($WalletsTable tbl) {
  Set<String>? pks = lensWalletPks;
  if (pks == null) return Constant(true);
  return tbl.walletPk.isIn(pks);
}

bool walletInCurrencyLens(String walletPk) =>
    lensWalletPks?.contains(walletPk) ?? true;

// Default account for a new transaction: the primary one, or the first
// account of the currency being viewed
String defaultWalletPkForLens(String primaryWalletPk) {
  Set<String>? pks = lensWalletPks;
  if (pks == null || pks.contains(primaryWalletPk)) return primaryWalletPk;
  for (TransactionWallet wallet in allWalletsUnfiltered.list)
    if (pks.contains(wallet.walletPk)) return wallet.walletPk;
  return primaryWalletPk;
}

Future setCurrencyLens(BuildContext context, String? currencyKey) async {
  await updateSettings(currencyLensSetting, currencyKey ?? "",
      updateGlobalState: false);
  applyCurrencyLens(allWalletsUnfiltered);
  // Rebuild every page so all totals and lists are queried again
  RestartApp.restartApp(context);
}

List<String> _currenciesOf(AllWallets all) {
  List<String> currencies = [];
  for (TransactionWallet wallet in all.list)
    if (wallet.currency != null && !currencies.contains(wallet.currency))
      currencies.add(wallet.currency!);
  return currencies;
}

String _symbolOf(String currencyKey) {
  if (currencyKey == "aed") return String.fromCharCode(0x20C3);
  return (currenciesJSON[currencyKey]?["Symbol"] ?? "").toString();
}

// Home header chip: "All" or "₹ INR"; only when accounts use several currencies
class CurrencyLensButton extends StatelessWidget {
  const CurrencyLensButton({super.key});

  @override
  Widget build(BuildContext context) {
    Provider.of<AllWallets>(context); // rebuild when accounts change
    String? lens = activeCurrencyLens;
    if (lens == null && _currenciesOf(allWalletsUnfiltered).length < 2)
      return SizedBox.shrink();
    return Tooltip(
      message: "currency-view".tr(),
      child: Tappable(
        borderRadius: 100,
        color: lens == null
            ? Colors.transparent
            : Theme.of(context).colorScheme.secondaryContainer,
        onTap: () => openCurrencyLensSheet(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lens == null)
                Icon(
                  appStateSettings["outlinedIcons"]
                      ? Icons.currency_exchange_outlined
                      : Icons.currency_exchange_rounded,
                  size: 18,
                  color: getColor(context, "textLight"),
                )
              else
                TextFont(text: _symbolOf(lens), fontSize: 16),
              SizedBox(width: 6),
              TextFont(
                text: lens == null ? "all".tr() : lens.toUpperCase(),
                fontSize: 15,
                fontWeight: FontWeight.bold,
                textColor: lens == null
                    ? getColor(context, "textLight")
                    : getColor(context, "black"),
              ),
              Icon(Icons.arrow_drop_down_rounded,
                  size: 20, color: getColor(context, "textLight")),
            ],
          ),
        ),
      ),
    );
  }
}

Future openCurrencyLensSheet(BuildContext pageContext) async {
  AllWallets all = allWalletsUnfiltered;
  String? base = chosenBaseCurrency(all);
  await openBottomSheet(
    pageContext,
    PopupFramework(
      title: "currency-view".tr(),
      subtitle: "currency-view-description".tr(),
      child: Column(
        children: [
          _LensRow(
            leading: Icon(Icons.currency_exchange_rounded, size: 20),
            title: "all-currencies".tr(),
            subtitle: base == null
                ? null
                : "converted-into".tr() + " " + base.toUpperCase(),
            selected: activeCurrencyLens == null,
            onTap: () => _choose(pageContext, null),
          ),
          for (String currency in _currenciesOf(all))
            _LensRow(
              leading: TextFont(text: _symbolOf(currency), fontSize: 18),
              title: currency.toUpperCase() +
                  "  ·  " +
                  (currenciesJSON[currency]?["Currency"] ?? "").toString(),
              subtitle: _accountCount(all, currency),
              selected: activeCurrencyLens == currency,
              onTap: () => _choose(pageContext, currency),
            ),
        ],
      ),
    ),
  );
}

String _accountCount(AllWallets all, String currency) {
  int count = all.list.where((w) => w.currency == currency).length;
  return count.toString() +
      " " +
      (count == 1 ? "account" : "accounts").tr().toLowerCase();
}

Future _choose(BuildContext pageContext, String? currency) async {
  popRoute(pageContext);
  if (currency == activeCurrencyLens) return;
  await setCurrencyLens(pageContext, currency);
}

class _LensRow extends StatelessWidget {
  const _LensRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      child: Tappable(
        borderRadius: 15,
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : getColor(context, "lightDarkAccentHeavyLight"),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16, vertical: 13),
          child: Row(
            children: [
              SizedBox(width: 30, child: Center(child: leading)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFont(
                        text: title,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        maxLines: 1),
                    if (subtitle != null)
                      TextFont(
                        text: subtitle!,
                        fontSize: 13,
                        textColor: getColor(context, "textLight"),
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded,
                    size: 20, color: Theme.of(context).colorScheme.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
