import 'package:budget/ameen/scopedCurrency.dart';
import 'package:budget/ameen/currencyLens.dart';
import 'package:budget/ameen/currencySheet.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Base currency: what totals are converted into. Upstream uses the primary
// account's currency for this; Ameen makes it its own setting so the primary
// account only means "default account for new transactions".
// Unset falls back to the primary account's currency (upstream behaviour).

const String baseCurrencySetting = "ameenBaseCurrency";

String? baseCurrencyOf(AllWallets allWallets,
    [Map<String, dynamic>? settings]) {
  // Budget and goal screens use the budget's or goal's currency
  if (allWallets is ScopedWallets) return allWallets.currency;
  // While viewing one currency, everything is shown in it
  if (activeCurrencyLens != null) return activeCurrencyLens;
  return chosenBaseCurrency(allWallets, settings);
}

// The Base Currency setting, ignoring the currency view
String? chosenBaseCurrency(AllWallets allWallets,
    [Map<String, dynamic>? settings]) {
  Map<String, dynamic> s = settings ?? appStateSettings;
  dynamic chosen = s[baseCurrencySetting];
  if (chosen is String && chosen != "") return chosen;
  return allWallets.indexedByPk[s["selectedWalletPk"]]?.currency;
}

// Decimals for amounts shown in the base currency: those of an account in
// that currency, the primary account's when it matches, otherwise 2
int baseCurrencyDecimals(AllWallets allWallets) {
  String? base = baseCurrencyOf(allWallets);
  TransactionWallet? primary =
      allWallets.indexedByPk[appStateSettings["selectedWalletPk"]];
  if (primary != null && primary.currency == base) return primary.decimals;
  for (TransactionWallet wallet in allWallets.list) {
    if (wallet.currency == base) return wallet.decimals;
  }
  return 2;
}

// Startup: existing installs keep their current base (the primary account's
// currency at the time), after which changing the primary account no longer
// changes the base
Future migrateBaseCurrency() async {
  dynamic chosen = appStateSettings[baseCurrencySetting];
  if (chosen is String && chosen != "") return;
  TransactionWallet? primary;
  try {
    primary = await database
        .getWalletInstance(appStateSettings["selectedWalletPk"].toString());
  } catch (_) {}
  if (primary?.currency == null) return;
  await updateSettings(baseCurrencySetting, primary!.currency,
      updateGlobalState: false);
}

Future setBaseCurrency(String currencyKey) async {
  // Global state update so every converted total and symbol refreshes
  await updateSettings(baseCurrencySetting, currencyKey,
      updateGlobalState: true);
}

class BaseCurrencySetting extends StatelessWidget {
  const BaseCurrencySetting({super.key});

  @override
  Widget build(BuildContext context) {
    String base =
        (baseCurrencyOf(Provider.of<AllWallets>(context)) ?? "").toUpperCase();
    return SettingsContainer(
      title: "base-currency".tr(),
      description: "base-currency-description".tr(),
      icon: appStateSettings["outlinedIcons"]
          ? Icons.currency_exchange_outlined
          : Icons.currency_exchange_rounded,
      onTap: () => openBaseCurrencyPicker(context),
      afterWidget: Tappable(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: 10,
        onTap: () => openBaseCurrencyPicker(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16, vertical: 10),
          child: TextFont(text: base, fontSize: 14),
        ),
      ),
    );
  }
}

Future openBaseCurrencyPicker(BuildContext context) async {
  AllWallets allWallets = Provider.of<AllWallets>(context, listen: false);
  String? picked = await pickCurrencySheet(
    context,
    title: "base-currency".tr(),
    subtitle: "base-currency-description".tr(),
    selected: baseCurrencyOf(allWallets),
    pinned: allWallets.list
        .map((w) => w.currency)
        .whereType<String>()
        .toSet()
        .toList(),
  );
  if (picked != null) await setBaseCurrency(picked);
}
