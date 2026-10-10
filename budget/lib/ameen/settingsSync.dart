import 'package:budget/ameen/recentPlaces.dart';
import 'package:budget/ameen/accountChoice.dart';
import 'dart:convert';

import 'package:budget/database/tables.dart';
import 'package:budget/struct/settings.dart';

// Account groups and frequent accounts live in settings, which upstream's
// sync does not merge. Every device's sync file already contains its settings
// (sync uploads are made by createBackup, which calls backupSettings), so when
// another device's file is merged we adopt its Ameen data if it changed more
// recently than ours. Last change wins for the whole set.

const String ameenSyncedModifiedSetting = "ameenSyncedSettingsModified";
const List<String> ameenSyncedSettingKeys = [
  "ameenWalletGroups",
  "ameenWalletGroupOf",
  "ameenFrequentWallets",
];

// Call after changing any of ameenSyncedSettingKeys
Future touchAmeenSyncedSettings() async {
  await updateSettings(
      ameenSyncedModifiedSetting, DateTime.now().toUtc().toIso8601String(),
      updateGlobalState: false);
}

DateTime? _parse(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

Map<String, dynamic>? pickNewerAmeenSettings(
    Map<String, dynamic> local, Map<String, dynamic> remote) {
  DateTime? remoteTime = _parse(remote[ameenSyncedModifiedSetting]);
  if (remoteTime == null) return null;
  DateTime? localTime = _parse(local[ameenSyncedModifiedSetting]);
  if (localTime != null && !remoteTime.isAfter(localTime)) return null;
  return {
    for (String key in [...ameenSyncedSettingKeys, ameenSyncedModifiedSetting])
      if (remote.containsKey(key)) key: remote[key]
  };
}

// Called by upstream's sync for each other device's database
Future mergeAmeenSyncedSettings(FinanceDatabase otherDevice) async {
  try {
    Map<String, dynamic> remote =
        json.decode((await otherDevice.getSettings()).settingsJSON);
    await mergeTitleAccountsFrom(remote);
    await mergeRecentPlacesFrom(remote);
    Map<String, dynamic>? newer =
        pickNewerAmeenSettings(appStateSettings, remote);
    if (newer == null) return;
    for (MapEntry<String, dynamic> entry in newer.entries) {
      await updateSettings(entry.key, entry.value, updateGlobalState: false);
    }
    print("Merged Ameen settings from another device");
  } catch (e) {
    print("Could not merge Ameen settings: " + e.toString());
  }
}
