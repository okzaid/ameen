import 'package:budget/ameen/baseCurrency.dart';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Budgets and goals in their own currency. A budget's currency is its
// account's (Budget.walletFk, chosen on its amount pad). Cashew converts
// everything on budget and goal screens into one base currency; inside a
// CurrencyScope the "base" is the budget's currency instead, so every total,
// limit and amount there is computed and shown in it. When the budget only
// counts accounts of its own currency, its totals are exact.

// AllWallets whose base currency is fixed (read by baseCurrencyOf)
class ScopedWallets extends AllWallets {
  ScopedWallets(AllWallets wallets, this.currency)
      : super(list: wallets.list, indexedByPk: wallets.indexedByPk);
  final String currency;
}

class CurrencyScope extends StatelessWidget {
  const CurrencyScope({required this.currency, required this.child, super.key});
  final String currency;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    AllWallets wallets = Provider.of<AllWallets>(context);
    return Provider<AllWallets>.value(
      value: ScopedWallets(wallets, currency),
      updateShouldNotify: (_, __) => true,
      child: child,
    );
  }
}

String? _currencyOfWallet(BuildContext context, String walletPk) =>
    Provider.of<AllWallets>(context, listen: false)
        .indexedByPk[walletPk]
        ?.currency;

// For a widget's build: the widget again inside its currency's scope, or null
// when it is already scoped or uses the base currency anyway.
//   Widget? scoped = scopeToWalletCurrency(context, budget.walletFk, this);
//   if (scoped != null) return scoped;
Widget? scopeToWalletCurrency(
    BuildContext context, String walletPk, Widget self) {
  AllWallets wallets = Provider.of<AllWallets>(context, listen: false);
  if (wallets is ScopedWallets) return null;
  String? currency = _currencyOfWallet(context, walletPk);
  if (currency == null || currency == baseCurrencyOf(wallets)) return null;
  return CurrencyScope(currency: currency, child: self);
}

// Around a page's content
Widget walletCurrencyScope(
    BuildContext context, String walletPk, Widget child) {
  String? currency = _currencyOfWallet(context, walletPk);
  if (currency == null) return child;
  return CurrencyScope(currency: currency, child: child);
}

// ---- Budget editor: which accounts count -----------------------------------

List<String> walletPksOfCurrency(AllWallets wallets, String? currency) => [
      for (TransactionWallet wallet in wallets.list)
        if (wallet.currency == currency) wallet.walletPk
    ];

bool isOnlyCurrencyAccounts(
    AllWallets wallets, String? currency, List<String>? walletFks) {
  if (walletFks == null || currency == null) return false;
  List<String> pks = walletPksOfCurrency(wallets, currency);
  return walletFks.length == pks.length && pks.every(walletFks.contains);
}

// Changes when the mode chips replace the account selection, so the account
// chips below start again from the new selection
int budgetCurrencyModeVersion = 0;

// "Count: Only ₹ accounts · All currencies (≈)" above the account chips.
// Hidden when every account uses one currency.
class BudgetCurrencyMode extends StatelessWidget {
  const BudgetCurrencyMode({
    required this.walletPk,
    required this.walletFks,
    required this.onChanged,
    super.key,
  });
  final String walletPk; // the budget's amount account
  final List<String>? walletFks;
  final Function(List<String>?) onChanged;

  @override
  Widget build(BuildContext context) {
    AllWallets wallets = Provider.of<AllWallets>(context);
    if (wallets.allContainSameCurrency()) return SizedBox.shrink();
    String? currency = wallets.indexedByPk[walletPk]?.currency;
    if (currency == null) return SizedBox.shrink();
    bool only = isOnlyCurrencyAccounts(wallets, currency, walletFks);
    String symbol = currency == "aed"
        ? String.fromCharCode(0x20C3)
        : (currenciesJSON[currency]?["Symbol"] ?? currency.toUpperCase())
            .toString();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 5),
      child: SelectChips<bool>(
        items: [true, false],
        getLabel: (exact) => exact
            ? "only-currency-accounts".tr(namedArgs: {"currency": symbol})
            : "all-currencies-converted".tr(),
        getSelected: (exact) => exact == only,
        onSelected: (exact) {
          if (exact == only) return;
          budgetCurrencyModeVersion++;
          onChanged(exact ? walletPksOfCurrency(wallets, currency) : null);
        },
        extraWidgetBefore: Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, end: 4),
          child: Icon(Icons.currency_exchange_rounded,
              size: 18, color: getColor(context, "textLight")),
        ),
      ),
    );
  }
}

// For a stateful page's build (the account page): runs [build] inside the
// account's currency, so its totals are in it instead of the base currency
Widget buildInWalletCurrency(BuildContext context, String? walletPk,
    Widget Function(BuildContext context) build) {
  String? currency =
      walletPk == null ? null : _currencyOfWallet(context, walletPk);
  if (currency == null) return build(context);
  return CurrencyScope(currency: currency, child: Builder(builder: build));
}
