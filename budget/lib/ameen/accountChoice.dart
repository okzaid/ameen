import 'package:budget/ameen/currencyLens.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/editWalletsPage.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/walletEntry.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// No primary account when adding things: a new transaction starts without an
// account and asks for one at Save, unless the choice is obvious (a single
// account, a single account in the currency view, or the account the title
// was last saved on). Cashew's primary account ("selectedWalletPk") stays as
// the Default Account, used only where nothing can be asked (links from other
// apps, the home-screen widget, imports) and as upstream's internal fallback.

// No account chosen yet (not a walletPk)
const String noAccountChosen = "";

bool isAccountChosen(AllWallets allWallets, String walletPk) =>
    allWallets.indexedByPk.containsKey(walletPk);

// Accounts the user can pick from right now (the currency view's, or all)
List<TransactionWallet> _pickableAccounts() {
  Set<String>? lens = lensWalletPks;
  return [
    for (TransactionWallet wallet in allWalletsUnfiltered.list)
      if (lens == null || lens.contains(wallet.walletPk)) wallet
  ];
}

// For a new transaction: the only account, or none
String initialAccountForNewTransaction() {
  List<TransactionWallet> accounts = _pickableAccounts();
  if (accounts.length == 1) return accounts.first.walletPk;
  return noAccountChosen;
}

// At Save without an account: ask. Returns the walletPk, or null if dismissed.
Future<String?> askForAccount(BuildContext context) async {
  TransactionWallet? wallet = await selectWalletPopup(
    context,
    allowEditWallet: false,
    allowDeleteWallet: false,
    subtitle: "select-account-to-save".tr(),
  );
  return wallet?.walletPk;
}

// ---- Title → account -------------------------------------------------------
// Learned from saves: {"lulu": {"w": walletPk, "t": "2026-10-08T…Z"}}.
// Per-entry times so devices merge entry by entry when syncing.

const String titleAccountsSetting = "ameenTitleAccounts";

String _key(String title) => title.trim().toLowerCase();

Map<String, dynamic> _titleAccounts([Map<String, dynamic>? settings]) {
  dynamic stored = (settings ?? appStateSettings)[titleAccountsSetting];
  return stored is Map ? Map<String, dynamic>.from(stored) : {};
}

// The account a title was last saved on, if it still exists and can be picked
String? accountForTitle(String? title) {
  if (title == null || title.trim() == "") return null;
  dynamic entry = _titleAccounts()[_key(title)];
  String? walletPk = entry is Map ? entry["w"]?.toString() : null;
  if (walletPk == null) return null;
  if (!_pickableAccounts().any((w) => w.walletPk == walletPk)) return null;
  return walletPk;
}

Future rememberTitleAccount(String? title, String walletPk) async {
  if (title == null || title.trim() == "" || walletPk == noAccountChosen)
    return;
  if (appStateSettings["autoAddAssociatedTitles"] == false) return;
  Map<String, dynamic> links = _titleAccounts();
  dynamic current = links[_key(title)];
  if (current is Map && current["w"] == walletPk) return;
  links[_key(title)] = {
    "w": walletPk,
    "t": DateTime.now().toUtc().toIso8601String(),
  };
  await updateSettings(titleAccountsSetting, links, updateGlobalState: false);
}

// Newest entry per title wins
Map<String, dynamic> mergeTitleAccounts(
    Map<String, dynamic> local, Map<String, dynamic> remote) {
  Map<String, dynamic> merged = {...local};
  remote.forEach((title, entry) {
    if (entry is! Map) return;
    dynamic mine = merged[title];
    DateTime? theirs = DateTime.tryParse(entry["t"]?.toString() ?? "");
    DateTime? ours =
        mine is Map ? DateTime.tryParse(mine["t"]?.toString() ?? "") : null;
    if (theirs == null) return;
    if (ours == null || theirs.isAfter(ours)) merged[title] = entry;
  });
  return merged;
}

Future mergeTitleAccountsFrom(Map<String, dynamic> remoteSettings) async {
  Map<String, dynamic> remote = _titleAccounts(remoteSettings);
  if (remote.isEmpty) return;
  Map<String, dynamic> local = _titleAccounts();
  Map<String, dynamic> merged = mergeTitleAccounts(local, remote);
  if (merged.toString() == local.toString()) return;
  await updateSettings(titleAccountsSetting, merged, updateGlobalState: false);
}

// ---- Settings: Default Account (Cashew's primary account) ------------------

class DefaultAccountSetting extends StatelessWidget {
  const DefaultAccountSetting({super.key});

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    String selectedPk = Provider.of<SelectedWalletPk>(context).selectedWalletPk;
    TransactionWallet? current = allWalletsUnfiltered.indexedByPk[selectedPk] ??
        allWallets.indexedByPk[selectedPk];
    if (allWalletsUnfiltered.list.length <= 1) return SizedBox.shrink();
    return SettingsContainer(
      title: "default-account".tr(),
      description: "default-account-description".tr(),
      icon: appStateSettings["outlinedIcons"]
          ? Icons.account_balance_wallet_outlined
          : Icons.account_balance_wallet_rounded,
      onTap: () => _pickDefaultAccount(context, current),
      afterWidget: Tappable(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: 10,
        onTap: () => _pickDefaultAccount(context, current),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16, vertical: 10),
          child: TextFont(text: current?.name ?? "", fontSize: 14, maxLines: 1),
        ),
      ),
    );
  }
}

Future _pickDefaultAccount(
    BuildContext context, TransactionWallet? current) async {
  TransactionWallet? wallet = await selectWalletPopup(
    context,
    title: "default-account".tr(),
    subtitle: "default-account-description".tr(),
    selectedWallet: current,
    allowEditWallet: false,
    allowDeleteWallet: false,
  );
  if (wallet == null) return;
  await setPrimaryWallet(wallet.walletPk, allWallets: allWalletsUnfiltered);
}
