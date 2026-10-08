import 'package:budget/ameen/foreignAmount.dart';
import 'package:budget/ameen/noteTags.dart';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/selectAmount.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Transfers between accounts of different currencies with the real amounts:
// what left one account and what arrived in the other (the bank's actual rate
// and fees). Each side keeps the other side's amount in a hidden note tag:
//   ⇄INR 22600.00

// "Received" typed by the user, only valid for the accounts it was typed for
class ReceivedOverride {
  const ReceivedOverride(this.fromPk, this.toPk, this.amount);
  final String fromPk;
  final String toPk;
  final double amount; // positive, in the receiving account's currency
}

class TransferAmounts {
  const TransferAmounts(this.from, this.to);
  final double from; // signed, for the sending account
  final double to; // signed, for the receiving account
}

double _round(double value, int decimals) =>
    double.parse(value.toStringAsFixed(decimals));

// entered: signed amount typed in [enteredCurrency] (negative = reversed
// direction, as upstream's arrow does)
TransferAmounts transferAmounts({
  required double entered,
  required String? enteredCurrency,
  required TransactionWallet from,
  required TransactionWallet to,
  ReceivedOverride? received,
}) {
  double sign = entered < 0 ? -1 : 1;
  double amount = entered.abs();
  String? currency = enteredCurrency ?? from.currency;
  double sent = currency == null || from.currency == null
      ? amount
      : _round(amount * marketRate(currency, from.currency), from.decimals);
  double arrived = currency == null || to.currency == null
      ? amount
      : _round(amount * marketRate(currency, to.currency), to.decimals);
  if (received != null &&
      received.fromPk == from.walletPk &&
      received.toPk == to.walletPk) arrived = received.amount;
  return TransferAmounts(-sign * sent, sign * arrived);
}

// Note for one side: upstream's note plus the other side's amount and the
// base rate
String transferNote({
  required String note,
  required TransactionWallet self,
  required TransactionWallet other,
  required double otherAmount,
  required AllWallets allWallets,
}) {
  Map<String, String> tags = {};
  if (self.currency != other.currency && other.currency != null)
    tags[transferTag] = other.currency!.toUpperCase() +
        " " +
        otherAmount.abs().toStringAsFixed(other.decimals);
  String? rate = baseRatePayload(allWallets, self.currency);
  if (rate != null) tags[baseRateTag] = rate;
  return noteWithAmeenTags(note, tags);
}

// "⇄ ₹22,600" for transaction rows
String? transferCounterpartText(AllWallets allWallets, String? note) {
  String? payload = ameenTagsOf(note)[transferTag];
  if (payload == null) return null;
  List<String> parts = payload.trim().split(" ");
  if (parts.length != 2) return null;
  double? amount = double.tryParse(parts[1]);
  if (amount == null) return null;
  return "⇄ " +
      convertToMoney(allWallets, amount, currencyKey: parts[0].toLowerCase());
}

// Under the transfer amount when the two accounts use different currencies
class TransferReceivedRow extends StatelessWidget {
  const TransferReceivedRow({
    required this.entered,
    required this.enteredCurrency,
    required this.from,
    required this.to,
    required this.received,
    required this.onReceivedChanged,
    super.key,
  });
  final double entered;
  final String? enteredCurrency;
  final TransactionWallet? from;
  final TransactionWallet? to;
  final ReceivedOverride? received;
  final Function(ReceivedOverride?) onReceivedChanged;

  @override
  Widget build(BuildContext context) {
    TransactionWallet? from = this.from;
    TransactionWallet? to = this.to;
    if (from == null || to == null || from.currency == to.currency)
      return SizedBox.shrink();
    AllWallets allWallets = Provider.of<AllWallets>(context);
    TransferAmounts amounts = transferAmounts(
      entered: entered,
      enteredCurrency: enteredCurrency,
      from: from,
      to: to,
      received: received,
    );
    // Show the direction the money actually moves
    bool reversed = entered < 0;
    TransactionWallet payer = reversed ? to : from;
    TransactionWallet payee = reversed ? from : to;
    double paid = (reversed ? amounts.to : amounts.from).abs();
    double got = (reversed ? amounts.from : amounts.to).abs();
    String rate = paid == 0
        ? ""
        : "  ·  1 " +
            (payer.currency ?? "").toUpperCase() +
            " = " +
            (got / paid).toStringAsFixed(4) +
            " " +
            (payee.currency ?? "").toUpperCase();
    bool overridden = received != null &&
        received!.fromPk == from.walletPk &&
        received!.toPk == to.walletPk;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4, bottom: 8),
      child: Tappable(
        borderRadius: 12,
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        onTap: () => openBottomSheet(
          context,
          fullSnap: true,
          PopupFramework(
            title: "amount-received".tr(),
            subtitle: payee.name,
            hasPadding: false,
            underTitleSpace: false,
            child: SelectAmount(
              padding: EdgeInsetsDirectional.symmetric(horizontal: 18),
              walletPkForCurrency: to.walletPk,
              selectedWalletPk: to.walletPk,
              currencyKey: to.currency,
              decimals: to.decimals,
              onlyShowCurrencyIcon: true,
              amountPassed: amounts.to.abs().toString(),
              setSelectedAmount: (amount, _) => onReceivedChanged(
                  ReceivedOverride(from.walletPk, to.walletPk, amount.abs())),
              next: () => popRoute(context),
              nextLabel: "set-amount".tr(),
            ),
          ),
        ),
        child: Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.currency_exchange_rounded,
                  size: 18, color: Theme.of(context).colorScheme.secondary),
              SizedBox(width: 8),
              Expanded(
                child: TextFont(
                  text: payee.name +
                      " " +
                      "receives".tr() +
                      " " +
                      convertToMoney(allWallets, got,
                          currencyKey: payee.currency,
                          decimals: payee.decimals) +
                      rate,
                  fontSize: 14,
                  maxLines: 3,
                ),
              ),
              if (overridden)
                Tappable(
                  borderRadius: 100,
                  onTap: () => onReceivedChanged(null),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(4),
                    child: Icon(Icons.restart_alt_rounded,
                        size: 18, color: getColor(context, "textLight")),
                  ),
                )
              else
                Icon(Icons.edit_rounded,
                    size: 16, color: getColor(context, "textLight")),
            ],
          ),
        ),
      ),
    );
  }
}
