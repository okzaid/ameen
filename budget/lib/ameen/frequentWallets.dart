import 'package:budget/ameen/settingsSync.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Frequent accounts: when there are many accounts, the add transaction page
// shows only the frequent ones (plus the selected and primary account) as
// chips. The rest stay one tap away behind upstream's "show all" button.

const String frequentWalletsSetting = "ameenFrequentWallets";
// With this many accounts or fewer, every account is always shown
const int showAllWalletsUpTo = 5;

List<String> getFrequentWalletPks() {
  dynamic stored = appStateSettings[frequentWalletsSetting];
  if (stored is List) return stored.map((e) => e.toString()).toList();
  return [];
}

bool isFrequentWallet(String walletPk) =>
    getFrequentWalletPks().contains(walletPk);

Future setFrequentWallet(String walletPk, bool frequent) async {
  List<String> pks = getFrequentWalletPks()..remove(walletPk);
  if (frequent) pks.add(walletPk);
  await updateSettings(frequentWalletsSetting, pks, updateGlobalState: false);
  await touchAmeenSyncedSettings();
}

// Accounts to show as chips on the add transaction page
List<TransactionWallet> walletsForTransactionChips(
  List<TransactionWallet> wallets, {
  required String? selectedWalletPk,
  required bool canShowAll,
}) {
  if (canShowAll == false || wallets.length <= showAllWalletsUpTo)
    return wallets;
  Set<String> frequent = getFrequentWalletPks().toSet();
  if (frequent.isEmpty) return wallets;
  return wallets
      .where((wallet) =>
          frequent.contains(wallet.walletPk) ||
          wallet.walletPk == selectedWalletPk)
      .toList();
}

// Switch on the add/edit account page
class FrequentWalletToggle extends StatelessWidget {
  const FrequentWalletToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final bool value;
  final Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsContainerSwitch(
      title: "frequent-account".tr(),
      description: "frequent-account-description".tr(),
      initialValue: value,
      onSwitched: (value) => onChanged(value),
      icon: appStateSettings["outlinedIcons"]
          ? Icons.push_pin_outlined
          : Icons.push_pin_rounded,
    );
  }
}
