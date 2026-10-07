import 'package:budget/ameen/perCurrency.dart';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/editRowEntry.dart';
import 'package:budget/widgets/fab.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:drift/drift.dart' show Value;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Account groups (e.g. "Banks", "Cash", "Cards").
//
// Stored in appStateSettings (included in backups) so upstream's database
// schema is untouched:
//   ameenWalletGroups:  [{"pk", "name"}] in display order
//   ameenWalletGroupOf: {walletPk: groupPk}
// Wallet `order` is kept grouped (group by group) so upstream's reorderable
// accounts list and every other account list show grouped accounts in order.

const String walletGroupsSetting = "ameenWalletGroups";
const String walletGroupOfSetting = "ameenWalletGroupOf";

class WalletGroup {
  WalletGroup({required this.pk, required this.name});
  final String pk;
  String name;

  Map<String, dynamic> toJson() => {"pk": pk, "name": name};
  static WalletGroup fromJson(dynamic json) =>
      WalletGroup(pk: json["pk"].toString(), name: json["name"].toString());
}

List<WalletGroup> getWalletGroups() {
  try {
    return [
      for (dynamic group in (appStateSettings[walletGroupsSetting] ?? []))
        WalletGroup.fromJson(group)
    ];
  } catch (e) {
    print("Error reading account groups " + e.toString());
    return [];
  }
}

bool hasWalletGroups() => getWalletGroups().isNotEmpty;

Map<String, String> _getWalletGroupOf() {
  Map<String, String> groupOf = {};
  dynamic stored = appStateSettings[walletGroupOfSetting];
  if (stored is Map) {
    stored.forEach((key, value) {
      if (value != null) groupOf[key.toString()] = value.toString();
    });
  }
  return groupOf;
}

// The group a wallet belongs to, null when ungrouped or the group was deleted
String? walletGroupPkOf(String walletPk) {
  String? groupPk = _getWalletGroupOf()[walletPk];
  if (groupPk == null) return null;
  if (getWalletGroups().any((group) => group.pk == groupPk)) return groupPk;
  return null;
}

WalletGroup? walletGroupOf(String walletPk) {
  String? groupPk = walletGroupPkOf(walletPk);
  if (groupPk == null) return null;
  return getWalletGroups().firstWhere((group) => group.pk == groupPk);
}

Future _saveWalletGroups(List<WalletGroup> groups) async {
  await updateSettings(
    walletGroupsSetting,
    [for (WalletGroup group in groups) group.toJson()],
    updateGlobalState: false,
  );
}

Future _saveWalletGroupOf(Map<String, String> groupOf) async {
  await updateSettings(walletGroupOfSetting, groupOf,
      updateGlobalState: false);
}

Future<WalletGroup> createWalletGroup(String name) async {
  WalletGroup group = WalletGroup(pk: uuid.v4(), name: name.trim());
  await _saveWalletGroups([...getWalletGroups(), group]);
  return group;
}

Future renameWalletGroup(String groupPk, String name) async {
  List<WalletGroup> groups = getWalletGroups();
  for (WalletGroup group in groups) {
    if (group.pk == groupPk) group.name = name.trim();
  }
  await _saveWalletGroups(groups);
}

Future deleteWalletGroup(String groupPk) async {
  await _saveWalletGroups(
      getWalletGroups().where((group) => group.pk != groupPk).toList());
  Map<String, String> groupOf = _getWalletGroupOf()
    ..removeWhere((walletPk, pk) => pk == groupPk);
  await _saveWalletGroupOf(groupOf);
  await normalizeWalletOrderForGroups();
}

Future moveWalletGroup(int oldIndex, int newIndex) async {
  List<WalletGroup> groups = getWalletGroups();
  WalletGroup group = groups.removeAt(oldIndex);
  groups.insert(newIndex.clamp(0, groups.length), group);
  await _saveWalletGroups(groups);
  await normalizeWalletOrderForGroups();
}

Future setWalletGroup(String walletPk, String? groupPk,
    {bool normalizeOrder = true}) async {
  Map<String, String> groupOf = _getWalletGroupOf();
  if (groupPk == null) {
    groupOf.remove(walletPk);
  } else {
    groupOf[walletPk] = groupPk;
  }
  await _saveWalletGroupOf(groupOf);
  if (normalizeOrder) await normalizeWalletOrderForGroups();
}

// Called by the add/edit account page after it saves
Future saveWalletGroupAfterWalletSaved({
  required String? existingWalletPk,
  required int? insertedRowId,
  required String? groupPk,
}) async {
  String? walletPk = existingWalletPk;
  if (walletPk == null && insertedRowId != null) {
    walletPk = (await database.getWalletFromRowId(insertedRowId)).walletPk;
  }
  if (walletPk == null) return;
  if (walletGroupPkOf(walletPk) == groupPk) return;
  await setWalletGroup(walletPk, groupPk);
}

// Keeps wallet order grouped: groups in their order, ungrouped accounts last,
// each wallet keeping its relative order inside its group
Future normalizeWalletOrderForGroups() async {
  List<WalletGroup> groups = getWalletGroups();
  if (groups.isEmpty) return;
  Map<String, int> groupIndex = {
    for (int i = 0; i < groups.length; i++) groups[i].pk: i
  };
  List<TransactionWallet> wallets = await database.getAllWallets();
  int indexOf(TransactionWallet wallet) =>
      groupIndex[walletGroupPkOf(wallet.walletPk)] ?? groups.length;
  List<TransactionWallet> sorted = [...wallets]..sort((a, b) {
      int byGroup = indexOf(a).compareTo(indexOf(b));
      if (byGroup != 0) return byGroup;
      return a.order.compareTo(b.order);
    });
  // Update in place (not insert-or-replace) so row ids stay stable
  for (int i = 0; i < sorted.length; i++) {
    if (sorted[i].order != i) {
      String walletPk = sorted[i].walletPk;
      await (database.update(database.wallets)
            ..where((w) => w.walletPk.equals(walletPk)))
          .write(WalletsCompanion(
        order: Value(i),
        dateTimeModified: Value(DateTime.now()),
      ));
    }
  }
}

// After a drag on the accounts page: the account joins the group it was
// dropped into (the group of the account above it, or below it at the top)
Future assignWalletGroupAfterReorder(
    List<TransactionWallet> walletsBefore, int oldIndex, int newIndex) async {
  if (hasWalletGroups() == false) return;
  List<TransactionWallet> wallets = [...walletsBefore];
  TransactionWallet moved = wallets.removeAt(oldIndex);
  int insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
  insertIndex = insertIndex.clamp(0, wallets.length);
  wallets.insert(insertIndex, moved);
  TransactionWallet? neighbour = insertIndex > 0
      ? wallets[insertIndex - 1]
      : (wallets.length > 1 ? wallets[1] : null);
  String? groupPk =
      neighbour == null ? null : walletGroupPkOf(neighbour.walletPk);
  await setWalletGroup(moved.walletPk, groupPk);
}

// Group name, number of accounts and totals shown above the first account of
// each group on the accounts page. The first item also gets the page total.
class WalletGroupSectionHeader extends StatelessWidget {
  const WalletGroupSectionHeader({
    required this.walletsWithDetails,
    required this.index,
    required this.enabled,
    required this.child,
    super.key,
  });
  final List<WalletWithDetails> walletsWithDetails;
  final int index;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled == false) return child;
    AllWallets allWallets = Provider.of<AllWallets>(context);
    List<Widget> above = [];

    if (index == 0 && walletsWithDetails.length > 1) {
      above.add(_TotalsHeader(
        title: "total".tr(),
        subtitle: null,
        totals: walletTotalsPerCurrency(walletsWithDetails),
        allWallets: allWallets,
        large: true,
      ));
    }

    if (hasWalletGroups()) {
      String? groupPk =
          walletGroupPkOf(walletsWithDetails[index].wallet.walletPk);
      String? previousGroupPk = index == 0
          ? "-start-"
          : walletGroupPkOf(walletsWithDetails[index - 1].wallet.walletPk);
      if (groupPk != previousGroupPk) {
        List<WalletWithDetails> members = walletsWithDetails
            .where((w) => walletGroupPkOf(w.wallet.walletPk) == groupPk)
            .toList();
        above.add(_TotalsHeader(
          title: groupPk == null
              ? "other-accounts".tr()
              : walletGroupOf(walletsWithDetails[index].wallet.walletPk)
                      ?.name ??
                  "",
          subtitle: members.length.toString() +
              " " +
              (members.length == 1
                  ? "account".tr().toLowerCase()
                  : "accounts".tr().toLowerCase()),
          totals: walletTotalsPerCurrency(members),
          allWallets: allWallets,
          large: false,
        ));
      }
    }

    if (above.isEmpty) return child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [...above, child],
    );
  }
}

class _TotalsHeader extends StatelessWidget {
  const _TotalsHeader({
    required this.title,
    required this.subtitle,
    required this.totals,
    required this.allWallets,
    required this.large,
  });
  final String title;
  final String? subtitle;
  final List<CurrencyTotal> totals;
  final AllWallets allWallets;
  final bool large;

  @override
  Widget build(BuildContext context) {
    bool perCurrency = showTotalsPerCurrency() && totals.length > 1;
    return Padding(
      padding: EdgeInsetsDirectional.only(
          start: 22, end: 22, top: large ? 4 : 14, bottom: large ? 10 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFont(
                  text: title,
                  fontSize: large ? 19 : 16,
                  fontWeight: FontWeight.bold,
                  textColor: large
                      ? getColor(context, "black")
                      : Theme.of(context).colorScheme.primary,
                  maxLines: 2,
                ),
                if (subtitle != null)
                  TextFont(
                    text: subtitle!,
                    fontSize: 13,
                    textColor: getColor(context, "textLight"),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10),
          perCurrency
              ? CurrencyTotalsText(
                  allWallets: allWallets,
                  totals: totals,
                  fontSize: large ? 19 : 16,
                  textAlign: TextAlign.end,
                )
              : TextFont(
                  text: formatTotals(allWallets, totals),
                  fontSize: large ? 19 : 16,
                  fontWeight: FontWeight.bold,
                  textAlign: TextAlign.end,
                ),
        ],
      ),
    );
  }
}

Future<String?> openWalletGroupNamePopup(BuildContext context,
    {String? initialName, required bool isNew}) async {
  String? result;
  await openBottomSheet(
    context,
    popupWithKeyboard: true,
    PopupFramework(
      title: isNew ? "add-account-group".tr() : "rename-account-group".tr(),
      child: SelectText(
        buttonLabel: isNew ? "add-account-group".tr() : "set-name".tr(),
        selectedText: initialName,
        icon: appStateSettings["outlinedIcons"]
            ? Icons.folder_outlined
            : Icons.folder_rounded,
        placeholder: "account-group-name-placeholder".tr(),
        setSelectedText: (_) {},
        nextWithInput: (text) {
          if (text.trim() != "") result = text.trim();
        },
        textCapitalization: TextCapitalization.words,
        autoFocus: true,
      ),
    ),
  );
  return result;
}

Future<String?> createWalletGroupFlow(BuildContext context) async {
  String? name = await openWalletGroupNamePopup(context, isNew: true);
  if (name == null) return null;
  return (await createWalletGroup(name)).pk;
}

Future<bool> deleteWalletGroupFlow(
    BuildContext context, WalletGroup group) async {
  DeletePopupAction? action = await openDeletePopup(
    context,
    title: "delete-account-group-question".tr(),
    subtitle: group.name,
    description: "delete-account-group-description".tr(),
  );
  if (action == DeletePopupAction.Delete) {
    await deleteWalletGroup(group.pk);
    return true;
  }
  return false;
}

// Group chips on the add/edit account page
class WalletGroupSelector extends StatefulWidget {
  const WalletGroupSelector({
    required this.selectedGroupPk,
    required this.onSelected,
    super.key,
  });
  final String? selectedGroupPk;
  final Function(String?) onSelected;

  @override
  State<WalletGroupSelector> createState() => _WalletGroupSelectorState();
}

class _WalletGroupSelectorState extends State<WalletGroupSelector> {
  @override
  Widget build(BuildContext context) {
    List<WalletGroup> groups = getWalletGroups();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 25, bottom: 5),
          child: TextFont(
            text: "account-group".tr(),
            fontSize: 15,
            fontWeight: FontWeight.bold,
            textColor: getColor(context, "textLight"),
          ),
        ),
        SelectChips<WalletGroup?>(
          items: [null, ...groups],
          allowMultipleSelected: false,
          getSelected: (group) => group?.pk == widget.selectedGroupPk,
          onSelected: (group) => widget.onSelected(group?.pk),
          getLabel: (group) => group?.name ?? "none".tr(),
          onLongPress: (group) async {
            if (group == null) return;
            await editWalletGroupOptions(context, group);
            if (getWalletGroups().every((g) => g.pk != widget.selectedGroupPk))
              widget.onSelected(null);
            setState(() {});
          },
          extraWidgetAfter: SelectChipsAddButtonExtraWidget(
            openPage: null,
            onTap: () async {
              String? groupPk = await createWalletGroupFlow(context);
              if (groupPk != null) widget.onSelected(groupPk);
              setState(() {});
            },
          ),
        ),
      ],
    );
  }
}

Future editWalletGroupOptions(BuildContext context, WalletGroup group) async {
  await openPopup(
    context,
    title: group.name,
    icon: appStateSettings["outlinedIcons"]
        ? Icons.folder_outlined
        : Icons.folder_rounded,
    onSubmitLabel: "rename".tr(),
    onSubmit: () async {
      popRoute(context);
      String? name = await openWalletGroupNamePopup(context,
          initialName: group.name, isNew: false);
      if (name != null) await renameWalletGroup(group.pk, name);
    },
    onCancelLabel: "delete".tr(),
    onCancel: () async {
      popRoute(context);
      await deleteWalletGroupFlow(context, group);
    },
  );
}

// "Account groups" row in the accounts settings
class WalletGroupsSettingsEntry extends StatelessWidget {
  const WalletGroupsSettingsEntry({this.backgroundColor, super.key});
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SettingsContainerOpenPage(
      backgroundColor: backgroundColor,
      openPage: EditWalletGroupsPage(),
      title: "account-groups".tr(),
      description: "account-groups-description".tr(),
      icon: appStateSettings["outlinedIcons"]
          ? Icons.folder_copy_outlined
          : Icons.folder_copy_rounded,
    );
  }
}

class EditWalletGroupsPage extends StatefulWidget {
  const EditWalletGroupsPage({super.key});

  @override
  State<EditWalletGroupsPage> createState() => _EditWalletGroupsPageState();
}

class _EditWalletGroupsPageState extends State<EditWalletGroupsPage> {
  int currentReorder = -1;

  Future addGroup() async {
    await createWalletGroupFlow(context);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<WalletGroup> groups = getWalletGroups();
    AllWallets allWallets = Provider.of<AllWallets>(context);
    return PageFramework(
      horizontalPaddingConstrained: true,
      dragDownToDismiss: true,
      title: "account-groups".tr(),
      floatingActionButton: AnimateFABDelayed(
        fab: AddFAB(
          tooltip: "add-account-group".tr(),
          onTap: addGroup,
        ),
      ),
      slivers: [
        if (groups.isEmpty)
          SliverToBoxAdapter(
            child: NoResults(message: "no-account-groups".tr()),
          ),
        SliverReorderableList(
          itemCount: groups.length,
          onReorderStart: (index) {
            HapticFeedback.heavyImpact();
            setState(() => currentReorder = index);
          },
          onReorderEnd: (_) => setState(() => currentReorder = -1),
          onReorder: (oldIndex, newIndex) async {
            await moveWalletGroup(
                oldIndex, newIndex > oldIndex ? newIndex - 1 : newIndex);
            setState(() {});
          },
          itemBuilder: (context, index) {
            WalletGroup group = groups[index];
            List<TransactionWallet> members = allWallets.list
                .where((w) => walletGroupPkOf(w.walletPk) == group.pk)
                .toList();
            return EditRowEntry(
              key: ValueKey(group.pk),
              index: index,
              canReorder: groups.length > 1,
              currentReorder: currentReorder != -1 && currentReorder != index,
              openPage: SizedBox.shrink(),
              onTap: () async {
                String? name = await openWalletGroupNamePopup(context,
                    initialName: group.name, isNew: false);
                if (name != null) await renameWalletGroup(group.pk, name);
                setState(() {});
              },
              onDelete: () async {
                bool deleted = await deleteWalletGroupFlow(context, group);
                setState(() {});
                return deleted;
              },
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFont(
                    text: group.name,
                    fontWeight: FontWeight.bold,
                    fontSize: 21,
                  ),
                  TextFont(
                    text: members.isEmpty
                        ? "no-accounts".tr()
                        : members.map((w) => w.name).join(", "),
                    fontSize: 14,
                    maxLines: 2,
                    textColor: getColor(context, "textLight"),
                  ),
                ],
              ),
            );
          },
        ),
        SliverToBoxAdapter(child: SizedBox(height: 85)),
      ],
    );
  }
}
