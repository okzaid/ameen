import 'package:budget/ameen/transfers.dart';
import 'package:budget/ameen/currencySheet.dart';
import 'package:budget/ameen/baseCurrency.dart';
import 'package:budget/ameen/locationTagging.dart';
import 'package:budget/ameen/noteTags.dart';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/transactionEntry/incomeAmountArrow.dart';
import 'package:budget/widgets/transactionEntry/transactionEntryAmount.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Foreign spend: paying $20 with an AED account. The transaction amount stays
// what the account was charged (Đ73.45); the original amount and the day's
// market rate are kept in a hidden note tag (see noteTags.dart):
//   ¤USD 20.00@3.672500   (1 USD = 3.6725 in the account's currency)
// The bank's FX fee is the charged amount compared to original × market rate.

class ForeignAmount {
  const ForeignAmount(this.currency, this.amount, this.marketRate);
  final String currency; // lowercase key, like account currencies
  final double amount; // always positive
  final double marketRate; // account currency per 1 unit of [currency]

  String toPayload() =>
      currency.toUpperCase() +
      " " +
      amount.toString() +
      "@" +
      marketRate.toStringAsFixed(6);

  static final RegExp _payload =
      RegExp(r"^([A-Za-z0-9]+) (\d+(?:\.\d+)?)@(\d+(?:\.\d+)?)$");

  static ForeignAmount? fromPayload(String? payload) {
    if (payload == null) return null;
    RegExpMatch? match = _payload.firstMatch(payload.trim());
    if (match == null) return null;
    double? amount = double.tryParse(match.group(2)!);
    double? rate = double.tryParse(match.group(3)!);
    if (amount == null || rate == null) return null;
    return ForeignAmount(match.group(1)!.toLowerCase(), amount, rate);
  }

  // Charged amount at the market rate (before any bank fee)
  double chargedAtMarket(int decimals) =>
      double.parse((amount * marketRate).toStringAsFixed(decimals));

  // Rate actually paid, from what the account was charged
  double effectiveRate(double charged) =>
      amount == 0 ? marketRate : charged.abs() / amount;

  // Bank fee as a fraction of the market value, e.g. 0.012 = 1.2%
  double feeFraction(double charged) {
    double market = amount * marketRate;
    if (market == 0) return 0;
    return (charged.abs() - market) / market;
  }
}

ForeignAmount? foreignAmountOf(Map<String, String> tags) =>
    ForeignAmount.fromPayload(tags[foreignAmountTag]);

ForeignAmount? foreignAmountOfNote(String? note) =>
    foreignAmountOf(ameenTagsOf(note));

double marketRate(String fromCurrency, String? toCurrency) =>
    toCurrency == null ? 1 : (amountRatioFromToCurrency(fromCurrency, toCurrency) ?? 1);

// Rate of the account's currency to the base, recorded at save time so totals
// can later use the rate of the transaction's date (multi-currency phase 6):
//   ≈AED>INR@22.730000   (1 AED = 22.73 INR)
String? baseRatePayload(AllWallets allWallets, String? walletCurrency) {
  String? base = baseCurrencyOf(allWallets);
  if (walletCurrency == null || base == null) return null;
  return walletCurrency.toUpperCase() +
      ">" +
      base.toUpperCase() +
      "@" +
      marketRate(walletCurrency, base).toStringAsFixed(6);
}

// Tags for a transaction being saved: location (new only), the base rate
// (new, or when the account's currency changed) and whatever is already set
Future<Map<String, String>> tagsForSave({
  required Map<String, String> tags,
  required bool isNew,
  required AllWallets allWallets,
  required String? walletCurrency,
}) async {
  Map<String, String> result = Map<String, String>.from(tags);
  if (isNew) {
    TransactionLocation? location = await locationForNewTransaction();
    if (location != null) result[locationTag] = location.toPayload();
  }
  String? existingRate = result[baseRateTag];
  bool rateStillValid = existingRate != null &&
      walletCurrency != null &&
      existingRate.toLowerCase().startsWith(walletCurrency.toLowerCase() + ">");
  if (isNew || !rateStillValid) {
    String? payload = baseRatePayload(allWallets, walletCurrency);
    if (payload != null) result[baseRateTag] = payload;
  }
  ForeignAmount? foreign = foreignAmountOf(result);
  if (foreign != null && foreign.currency == walletCurrency)
    result.remove(foreignAmountTag);
  return result;
}

List<String> recentForeignCurrencies() {
  dynamic stored = appStateSettings["ameenRecentForeignCurrencies"];
  if (stored is List) return stored.map((e) => e.toString()).toList();
  return [];
}

Future rememberForeignCurrency(String currency) async {
  List<String> recent = recentForeignCurrencies()..remove(currency);
  recent.insert(0, currency);
  await updateSettings("ameenRecentForeignCurrencies", recent.take(4).toList(),
      updateGlobalState: false);
}

// The amount pad for transactions with a "Paid in" currency choice.
// Typing in a foreign currency sets the charged amount at the market rate and
// remembers the original.
class ForeignAmountPad extends StatefulWidget {
  const ForeignAmountPad({
    required this.getWallet,
    required this.initialForeign,
    required this.initialAmount,
    required this.onAmount,
    required this.builder,
    super.key,
  });
  // The selected account, read live (it can change while the pad is open)
  final TransactionWallet? Function() getWallet;
  final ForeignAmount? initialForeign;
  final double? initialAmount; // charged amount
  // Charged amount (account currency) and the foreign original, if any
  final Function(double charged, String calculation, ForeignAmount? foreign)
      onAmount;
  final Widget Function(
    String? displayCurrency,
    String amountPassed,
    Widget currencyBar,
    void Function(double amount, String calculation) setAmount,
  ) builder;

  @override
  State<ForeignAmountPad> createState() => _ForeignAmountPadState();
}

class _ForeignAmountPadState extends State<ForeignAmountPad> {
  late String? foreignCurrency = widget.initialForeign?.currency;
  late double typed = widget.initialForeign?.amount ?? widget.initialAmount ?? 0;
  int padVersion = 0;

  String? get walletCurrency => widget.getWallet()?.currency;
  int get walletDecimals => widget.getWallet()?.decimals ?? 2;
  double get rate => marketRate(foreignCurrency!, walletCurrency);

  void setAmount(double amount, String calculation) {
    typed = amount.abs();
    if (foreignCurrency == null) {
      widget.onAmount(amount, calculation, null);
    } else {
      ForeignAmount foreign = ForeignAmount(foreignCurrency!, typed, rate);
      widget.onAmount(
          foreign.chargedAtMarket(walletDecimals), calculation, foreign);
    }
    setState(() {});
  }

  void pickCurrency(String? currency) {
    if (currency == walletCurrency) currency = null;
    setState(() {
      foreignCurrency = currency;
      padVersion++; // restart the pad so it shows the new currency
    });
    if (currency != null) rememberForeignCurrency(currency);
    setAmount(typed, typed.toString());
  }

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    List<String?> choices = [
      walletCurrency,
      ...recentForeignCurrencies().where((c) => c != walletCurrency),
      if (foreignCurrency != null &&
          !recentForeignCurrencies().contains(foreignCurrency))
        foreignCurrency,
    ];
    Widget bar = Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectChips<String?>(
            items: choices,
            allowMultipleSelected: false,
            getSelected: (c) => (foreignCurrency ?? walletCurrency) == c,
            onSelected: (c) => pickCurrency(c),
            getLabel: (c) => (c ?? "").toUpperCase(),
            extraWidgetBefore: Padding(
              padding: const EdgeInsetsDirectional.only(start: 5, end: 4),
              child: TextFont(
                text: "paid-in".tr(),
                fontSize: 14,
                textColor: getColor(context, "textLight"),
              ),
            ),
            extraWidgetAfter: SelectChipsAddButtonExtraWidget(
              openPage: null,
              iconData: Icons.more_horiz_rounded,
              onTap: () async {
                String? picked = await pickCurrencySheet(
                  context,
                  title: "paid-in".tr(),
                  selected: foreignCurrency ?? walletCurrency,
                  pinned: recentForeignCurrencies(),
                );
                if (picked != null) pickCurrency(picked);
              },
            ),
          ),
          if (foreignCurrency != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
              child: TextFont(
                text: "≈ " +
                    convertToMoney(
                      allWallets,
                      ForeignAmount(foreignCurrency!, typed, rate)
                          .chargedAtMarket(walletDecimals),
                      currencyKey: walletCurrency,
                      decimals: walletDecimals,
                    ) +
                    "  ·  1 " +
                    foreignCurrency!.toUpperCase() +
                    " = " +
                    rate.toStringAsFixed(4) +
                    " " +
                    (walletCurrency ?? "").toUpperCase(),
                fontSize: 14,
                maxLines: 2,
                textColor: getColor(context, "textLight"),
              ),
            ),
        ],
      ),
    );
    return KeyedSubtree(
      key: ValueKey(padVersion),
      child: widget.builder(
        foreignCurrency ?? walletCurrency,
        typed == 0 ? "0" : _plainNumber(typed),
        bar,
        setAmount,
      ),
    );
  }
}

String _plainNumber(double value) {
  String text = value.toString();
  if (text.endsWith(".0")) text = text.substring(0, text.length - 2);
  return text;
}

// Under the amount on the add transaction page: "Paid $20.00 · 1 USD = 3.6725 · fee 1.2%"
class ForeignAmountLine extends StatelessWidget {
  const ForeignAmountLine({
    required this.foreign,
    required this.charged,
    required this.walletCurrency,
    required this.onEditCharged,
    required this.onRemove,
    super.key,
  });
  final ForeignAmount? foreign;
  final double charged;
  final String? walletCurrency;
  final VoidCallback onEditCharged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    ForeignAmount? foreign = this.foreign;
    if (foreign == null || foreign.currency == walletCurrency)
      return SizedBox.shrink();
    AllWallets allWallets = Provider.of<AllWallets>(context);
    double fee = foreign.feeFraction(charged);
    String text = "paid".tr() +
        " " +
        convertToMoney(allWallets, foreign.amount,
            currencyKey: foreign.currency) +
        "  ·  1 " +
        foreign.currency.toUpperCase() +
        " = " +
        foreign.effectiveRate(charged).toStringAsFixed(4) +
        " " +
        (walletCurrency ?? "").toUpperCase() +
        (fee.abs() >= 0.0005
            ? "  ·  " +
                "bank-fee".tr() +
                " " +
                (fee * 100).toStringAsFixed(1) +
                "%"
            : "");
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 4),
      child: Tappable(
        borderRadius: 12,
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        onTap: onEditCharged,
        child: Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.currency_exchange_rounded,
                  size: 18, color: Theme.of(context).colorScheme.secondary),
              SizedBox(width: 8),
              Expanded(
                child: TextFont(text: text, fontSize: 14, maxLines: 2),
              ),
              Tappable(
                borderRadius: 100,
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(4),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: getColor(context, "textLight")),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Transaction rows: the account's own amount large ("native first"), with the
// foreign original or the ≈ base value underneath. Off = upstream's look.
const String nativeAmountsSetting = "ameenNativeTransactionAmounts";

bool showNativeTransactionAmounts() =>
    appStateSettings[nativeAmountsSetting] != false;

class NativeTransactionAmount extends StatelessWidget {
  const NativeTransactionAmount({required this.transaction, super.key});
  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    TransactionWallet? wallet = allWallets.indexedByPk[transaction.walletFk];
    Color color = getTransactionAmountColor(context, transaction);
    ForeignAmount? foreign = foreignAmountOfNote(transaction.note);
    String? base = baseCurrencyOf(allWallets);
    String? secondary;
    String? counterpart =
        transferCounterpartText(allWallets, transaction.note);
    if (foreign != null && foreign.currency != wallet?.currency) {
      secondary = convertToMoney(allWallets, foreign.amount,
          currencyKey: foreign.currency);
    } else if (counterpart != null) {
      secondary = counterpart;
    } else if (wallet?.currency != null && wallet?.currency != base) {
      secondary = "≈ " +
          convertToMoney(
            allWallets,
            transaction.amount.abs() *
                amountRatioToPrimaryCurrency(allWallets, wallet?.currency),
          );
    }
    bool hideArrow = (transaction.type == TransactionSpecialType.credit ||
            transaction.type == TransactionSpecialType.debt) &&
        transaction.paid == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            if (!hideArrow)
              IncomeOutcomeArrow(
                isIncome: transaction.income,
                color: color,
                width: 15,
                iconSize: 24,
              ),
            TextFont(
              text: convertToMoney(
                allWallets,
                transaction.amount.abs(),
                currencyKey: wallet?.currency,
                decimals: wallet?.decimals,
              ),
              fontSize: secondary == null ? 19 : 18,
              fontWeight: FontWeight.bold,
              textColor: color,
            ),
          ],
        ),
        if (secondary != null)
          TextFont(
            text: secondary,
            fontSize: 12,
            textColor: color,
          ),
      ],
    );
  }
}

class NativeTransactionAmountsSetting extends StatelessWidget {
  const NativeTransactionAmountsSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsContainerSwitch(
      title: "native-transaction-amounts".tr(),
      description: "native-transaction-amounts-description".tr(),
      initialValue: showNativeTransactionAmounts(),
      onSwitched: (value) => updateSettings(nativeAmountsSetting, value,
          updateGlobalState: true),
      icon: appStateSettings["outlinedIcons"]
          ? Icons.payments_outlined
          : Icons.payments_rounded,
    );
  }
}

// Account changed on the add transaction page: keep the foreign original and
// convert it into the new account's currency. Returns the updated tags and
// the new charged amount (null when there is no foreign amount).
(Map<String, String>, double?) reconvertForeignForWallet(
    Map<String, String> tags, TransactionWallet? wallet) {
  ForeignAmount? foreign = foreignAmountOf(tags);
  if (foreign == null || wallet == null) return (tags, null);
  Map<String, String> result = Map<String, String>.from(tags);
  if (foreign.currency == wallet.currency) {
    result.remove(foreignAmountTag);
    return (result, foreign.amount);
  }
  ForeignAmount updated = ForeignAmount(
      foreign.currency, foreign.amount, marketRate(foreign.currency, wallet.currency));
  result[foreignAmountTag] = updated.toPayload();
  return (result, updated.chargedAtMarket(wallet.decimals));
}
