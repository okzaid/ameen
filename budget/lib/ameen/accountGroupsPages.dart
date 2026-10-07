import 'package:budget/ameen/perCurrency.dart';
import 'package:budget/ameen/walletGroups.dart';
import 'package:budget/ameen/walletIcon.dart';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addWalletPage.dart';
import 'package:budget/pages/editWalletsPage.dart';
import 'package:budget/pages/transactionFilters.dart';
import 'package:budget/pages/walletDetailsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/categoryIcon.dart';
import 'package:budget/widgets/dropdownSelect.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/openContainerNavigation.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/transactionsAmountBox.dart';
import 'package:budget/widgets/util/keepAliveClientMixin.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

// Account groups overview: only groups and their balances on one screen.
// Opened from the home page section and the accounts page menu.

// A group, or the "Other Accounts" bucket (group == null), with its accounts
class WalletGroupSummary {
  WalletGroupSummary({required this.group, required this.walletsWithDetails});
  final WalletGroup? group;
  final List<WalletWithDetails> walletsWithDetails;

  String get name => group?.name ?? "other-accounts".tr();
  List<String> get walletPks =>
      walletsWithDetails.map((w) => w.wallet.walletPk).toList();
  List<CurrencyTotal> get totals => walletTotalsPerCurrency(walletsWithDetails);
  int get transactionCount => walletsWithDetails.fold(
      0, (sum, w) => sum + (w.numberTransactions ?? 0));
}

// Groups in their order, then "Other Accounts" when some accounts have no group
List<WalletGroupSummary> summarizeWalletGroups(
    List<WalletWithDetails> walletsWithDetails) {
  List<WalletGroupSummary> summaries = [];
  for (WalletGroup group in getWalletGroups()) {
    summaries.add(WalletGroupSummary(
      group: group,
      walletsWithDetails: walletsWithDetails
          .where((w) => walletGroupPkOf(w.wallet.walletPk) == group.pk)
          .toList(),
    ));
  }
  List<WalletWithDetails> ungrouped = walletsWithDetails
      .where((w) => walletGroupPkOf(w.wallet.walletPk) == null)
      .toList();
  if (ungrouped.isNotEmpty)
    summaries.add(
        WalletGroupSummary(group: null, walletsWithDetails: ungrouped));
  return summaries;
}

// The group's icon in a tinted tile, same look as category icons
class WalletGroupIcon extends StatelessWidget {
  const WalletGroupIcon({required this.group, this.size = 26, super.key});
  final WalletGroup? group;
  final double size;

  @override
  Widget build(BuildContext context) {
    String? image = walletIconImage(group?.iconName) ??
        (group == null ? "ms:more_horiz" : "ms:folder");
    String? emoji = walletIconEmoji(group?.iconName);
    return CategoryIcon(
      categoryPk: "-1",
      category: TransactionCategory(
        categoryPk: "-1",
        name: "",
        dateCreated: DateTime.now(),
        dateTimeModified: null,
        order: 0,
        income: false,
        iconName: emoji == null ? image : null,
        emojiIconName: emoji,
        colour: group?.colour,
      ),
      size: size,
      sizePadding: size * 0.6,
      borderRadius: 14,
      margin: EdgeInsetsDirectional.zero,
      canEditByLongPress: false,
      tintEnabled: false,
    );
  }
}

class AccountGroupsPage extends StatefulWidget {
  const AccountGroupsPage({super.key});

  @override
  State<AccountGroupsPage> createState() => _AccountGroupsPageState();
}

class _AccountGroupsPageState extends State<AccountGroupsPage> {
  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    return PageFramework(
      horizontalPaddingConstrained: true,
      dragDownToDismiss: true,
      title: "account-groups".tr(),
      actions: [
        CustomPopupMenuButton(
          showButtons: true,
          keepOutFirst: true,
          items: [
            DropdownItemMenu(
              id: "edit-groups",
              label: "edit-account-groups".tr(),
              icon: appStateSettings["outlinedIcons"]
                  ? Icons.edit_outlined
                  : Icons.edit_rounded,
              action: () async {
                await pushRoute(context, EditWalletGroupsPage());
                setState(() {});
              },
            ),
            DropdownItemMenu(
              id: "accounts",
              label: "edit-accounts".tr(),
              icon: appStateSettings["outlinedIcons"]
                  ? Icons.account_balance_wallet_outlined
                  : Icons.account_balance_wallet_rounded,
              action: () async {
                await pushRoute(context, EditWalletsPage());
                setState(() {});
              },
            ),
          ],
        ),
      ],
      slivers: [
        StreamBuilder<List<WalletWithDetails>>(
          stream: database.watchAllWalletsWithDetails(),
          builder: (context, snapshot) {
            if (snapshot.hasData == false)
              return SliverToBoxAdapter(child: SizedBox.shrink());
            List<WalletGroupSummary> summaries =
                summarizeWalletGroups(snapshot.data!);
            return SliverList(
              delegate: SliverChildListDelegate([
                WalletTotalsRow(
                  title: "total".tr(),
                  totals: walletTotalsPerCurrency(snapshot.data!),
                  allWallets: allWallets,
                  large: true,
                ),
                if (hasWalletGroups() == false)
                  NoResults(message: "no-account-groups".tr()),
                for (WalletGroupSummary summary in summaries)
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 13, vertical: 5),
                    child: WalletGroupCard(
                      summary: summary,
                      onClosed: () => setState(() {}),
                    ),
                  ),
                SizedBox(height: 85),
              ]),
            );
          },
        ),
      ],
    );
  }
}

// Title + per-currency totals, used above lists of groups/accounts
class WalletTotalsRow extends StatelessWidget {
  const WalletTotalsRow({
    required this.title,
    required this.totals,
    required this.allWallets,
    this.large = false,
    super.key,
  });
  final String title;
  final List<CurrencyTotal> totals;
  final AllWallets allWallets;
  final bool large;

  @override
  Widget build(BuildContext context) {
    bool perCurrency = showTotalsPerCurrency() && totals.length > 1;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
          start: 22, end: 22, top: 4, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFont(
              text: title,
              fontSize: large ? 19 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
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

// One group: icon, name, number of accounts and its balance per currency
class WalletGroupCard extends StatelessWidget {
  const WalletGroupCard({required this.summary, this.onClosed, super.key});
  final WalletGroupSummary summary;
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    int count = summary.walletsWithDetails.length;
    List<CurrencyTotal> totals = summary.totals;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadiusDirectional.circular(18),
        boxShadow: boxShadowCheck(boxShadowGeneral(context)),
      ),
      child: OpenContainerNavigation(
        borderRadius: 18,
        closedColor: getColor(context, "lightDarkAccentHeavyLight"),
        openPage: WalletGroupPage(groupPk: summary.group?.pk),
        onClosed: onClosed,
        button: (openContainer) {
          return Tappable(
            color: getColor(context, "lightDarkAccentHeavyLight"),
            borderRadius: 18,
            onTap: openContainer,
            onLongPress: summary.group == null
                ? null
                : () async {
                    await openWalletGroupEditor(context, summary.group);
                    onClosed?.call();
                  },
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  WalletGroupIcon(group: summary.group),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFont(
                          text: summary.name,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          maxLines: 2,
                        ),
                        TextFont(
                          text: count.toString() +
                              " " +
                              (count == 1
                                  ? "account".tr().toLowerCase()
                                  : "accounts".tr().toLowerCase()),
                          fontSize: 14,
                          textColor: getColor(context, "textLight"),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  showTotalsPerCurrency() && totals.length > 1
                      ? CurrencyTotalsText(
                          allWallets: allWallets,
                          totals: totals,
                          fontSize: 17,
                          textAlign: TextAlign.end,
                        )
                      : TextFont(
                          text: formatTotals(allWallets, totals),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          textAlign: TextAlign.end,
                        ),
                  Icon(
                    appStateSettings["outlinedIcons"]
                        ? Icons.chevron_right_outlined
                        : Icons.chevron_right_rounded,
                    color: getColor(context, "black").withOpacity(0.3),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// One group's page: totals, income/expense, its accounts and transactions
class WalletGroupPage extends StatefulWidget {
  const WalletGroupPage({required this.groupPk, super.key});
  // null is the "Other Accounts" bucket
  final String? groupPk;

  @override
  State<WalletGroupPage> createState() => _WalletGroupPageState();
}

class _WalletGroupPageState extends State<WalletGroupPage> {
  WalletGroup? get group => widget.groupPk == null
      ? null
      : getWalletGroups().cast<WalletGroup?>().firstWhere(
          (g) => g?.pk == widget.groupPk,
          orElse: () => null);

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    WalletGroup? currentGroup = group;
    return PageFramework(
      horizontalPaddingConstrained: true,
      dragDownToDismiss: true,
      title: currentGroup?.name ?? "other-accounts".tr(),
      actions: [
        if (currentGroup != null)
          CustomPopupMenuButton(
            showButtons: true,
            keepOutFirst: true,
            items: [
              DropdownItemMenu(
                id: "edit-group",
                label: "edit-account-group".tr(),
                icon: appStateSettings["outlinedIcons"]
                    ? Icons.edit_outlined
                    : Icons.edit_rounded,
                action: () async {
                  await openWalletGroupEditor(context, currentGroup);
                  setState(() {});
                },
              ),
              DropdownItemMenu(
                id: "delete-group",
                label: "delete-account-group".tr(),
                icon: appStateSettings["outlinedIcons"]
                    ? Icons.delete_outlined
                    : Icons.delete_rounded,
                action: () async {
                  if (await deleteWalletGroupFlow(context, currentGroup))
                    popRoute(context);
                },
              ),
            ],
          ),
      ],
      slivers: [
        StreamBuilder<List<WalletWithDetails>>(
          stream: database.watchAllWalletsWithDetails(),
          builder: (context, snapshot) {
            if (snapshot.hasData == false)
              return SliverToBoxAdapter(child: SizedBox.shrink());
            List<WalletWithDetails> members = snapshot.data!
                .where((w) =>
                    walletGroupPkOf(w.wallet.walletPk) == widget.groupPk)
                .toList();
            List<String> walletPks =
                members.map((w) => w.wallet.walletPk).toList();
            return SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                      start: 13, end: 13, bottom: 6),
                  child: Row(
                    children: [
                      WalletGroupIcon(group: currentGroup, size: 32),
                      SizedBox(width: 14),
                      Expanded(
                        child: showTotalsPerCurrency()
                            ? CurrencyTotalsText(
                                allWallets: allWallets,
                                totals: walletTotalsPerCurrency(members),
                                fontSize: 26,
                              )
                            : TextFont(
                                text: formatTotals(allWallets,
                                    walletTotalsPerCurrency(members)),
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                      ),
                    ],
                  ),
                ),
                if (members.isEmpty)
                  NoResults(message: "no-accounts-in-group".tr())
                else ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 13, vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: _GroupAmountBox(
                            label: "expense".tr(),
                            isIncome: false,
                            walletPks: walletPks,
                            textColor: getColor(context, "expenseAmount"),
                          ),
                        ),
                        SizedBox(width: 13),
                        Expanded(
                          child: _GroupAmountBox(
                            label: "income".tr(),
                            isIncome: true,
                            walletPks: walletPks,
                            textColor: getColor(context, "incomeAmount"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  for (WalletWithDetails walletWithDetails in members)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 13, vertical: 5),
                      child: _GroupAccountRow(
                          walletWithDetails: walletWithDetails),
                    ),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 13, vertical: 5),
                    child: _GroupLinkRow(
                      icon: Symbols.receipt_long_rounded,
                      label: "all-transactions".tr(),
                      openPage: WalletDetailsPage(
                        wallet: null,
                        initialSearchFilters:
                            SearchFilters(walletPks: walletPks),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 13, vertical: 5),
                  child: _GroupLinkRow(
                    icon: Symbols.add_rounded,
                    label: "add-account".tr(),
                    openPage: AddWalletPage(
                      routesToPopAfterDelete: RoutesToPopAfterDelete.None,
                      initialGroupPk: widget.groupPk,
                    ),
                    onClosed: () => setState(() {}),
                  ),
                ),
                SizedBox(height: 85),
              ]),
            );
          },
        ),
      ],
    );
  }
}

class _GroupAmountBox extends StatelessWidget {
  const _GroupAmountBox({
    required this.label,
    required this.isIncome,
    required this.walletPks,
    required this.textColor,
  });
  final String label;
  final bool isIncome;
  final List<String> walletPks;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    SearchFilters filters = SearchFilters(walletPks: walletPks);
    return TransactionsAmountBox(
      label: label,
      textColor: textColor,
      currencyTotalsStream: showTotalsPerCurrency()
          ? watchTotalsPerCurrency(
              allWallets: allWallets,
              walletPks: walletPks,
              isIncome: isIncome,
              followCustomPeriodCycle: true,
              cycleSettingsExtension: "AllSpendingSummary",
              onlyIncomeAndExpense: true,
            )
          : null,
      totalWithCountStream: database.watchTotalWithCountOfWallet(
        isIncome: isIncome,
        allWallets: allWallets,
        followCustomPeriodCycle: true,
        cycleSettingsExtension: "AllSpendingSummary",
        onlyIncomeAndExpense: true,
        searchFilters: filters,
      ),
      openPage: WalletDetailsPage(
        wallet: null,
        initialSearchFilters: filters.copyWith(
          expenseIncome: [
            isIncome ? ExpenseIncome.income : ExpenseIncome.expense
          ],
        ),
      ),
    );
  }
}

// An account inside a group, opens the account's own page
class _GroupAccountRow extends StatelessWidget {
  const _GroupAccountRow({required this.walletWithDetails});
  final WalletWithDetails walletWithDetails;

  @override
  Widget build(BuildContext context) {
    TransactionWallet wallet = walletWithDetails.wallet;
    Color walletColor = HexColor(wallet.colour,
        defaultColor: Theme.of(context).colorScheme.primary);
    int count = walletWithDetails.numberTransactions ?? 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadiusDirectional.circular(18),
        boxShadow: boxShadowCheck(boxShadowGeneral(context)),
      ),
      child: OpenContainerNavigation(
        borderRadius: 18,
        closedColor: getColor(context, "lightDarkAccentHeavyLight"),
        openPage: WatchedWalletDetailsPage(walletPk: wallet.walletPk),
        button: (openContainer) {
          return Tappable(
            color: getColor(context, "lightDarkAccentHeavyLight"),
            borderRadius: 18,
            onTap: openContainer,
            onLongPress: () => pushRoute(
              context,
              AddWalletPage(
                wallet: wallet,
                routesToPopAfterDelete: RoutesToPopAfterDelete.One,
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  walletHasIcon(wallet)
                      ? WalletIcon(wallet: wallet, size: 26)
                      : Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsetsDirectional.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: walletColor.withOpacity(0.7),
                          ),
                        ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFont(
                          text: wallet.name,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          maxLines: 2,
                        ),
                        TextFont(
                          text: count.toString() +
                              " " +
                              (count == 1
                                  ? "transaction".tr().toLowerCase()
                                  : "transactions".tr().toLowerCase()),
                          fontSize: 13,
                          textColor: getColor(context, "textLight"),
                        ),
                      ],
                    ),
                  ),
                  TextFont(
                    text: convertToMoney(
                      Provider.of<AllWallets>(context),
                      walletWithDetails.totalSpent ?? 0,
                      currencyKey: wallet.currency,
                      decimals: wallet.decimals,
                      addCurrencyName: Provider.of<AllWallets>(context)
                              .allContainSameCurrency() ==
                          false,
                    ),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GroupLinkRow extends StatelessWidget {
  const _GroupLinkRow({
    required this.icon,
    required this.label,
    required this.openPage,
    this.onClosed,
  });
  final IconData icon;
  final String label;
  final Widget openPage;
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    return OpenContainerNavigation(
      borderRadius: 18,
      closedColor: getColor(context, "lightDarkAccentHeavyLight"),
      openPage: openPage,
      onClosed: onClosed,
      button: (openContainer) {
        return Tappable(
          color: getColor(context, "lightDarkAccentHeavyLight"),
          borderRadius: 18,
          onTap: openContainer,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(icon,
                    fill: 1,
                    size: 24,
                    color: Theme.of(context).colorScheme.secondary),
                SizedBox(width: 12),
                Expanded(child: TextFont(text: label, fontSize: 16)),
                Icon(
                  appStateSettings["outlinedIcons"]
                      ? Icons.chevron_right_outlined
                      : Icons.chevron_right_rounded,
                  color: getColor(context, "black").withOpacity(0.3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Home page section: horizontal group cards, like the account switcher
class HomePageAccountGroups extends StatelessWidget {
  const HomePageAccountGroups({super.key});

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    return KeepAliveClientMixin(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 13.0),
        child: StreamBuilder<List<WalletWithDetails>>(
          stream: database.watchAllWalletsWithDetails(),
          builder: (context, snapshot) {
            if (snapshot.hasData == false) return SizedBox.shrink();
            List<WalletGroupSummary> summaries =
                summarizeWalletGroups(snapshot.data!);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 7),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (WalletGroupSummary summary in summaries)
                      _HomeGroupCard(summary: summary, allWallets: allWallets),
                    _HomeGroupCard(summary: null, allWallets: allWallets),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeGroupCard extends StatelessWidget {
  const _HomeGroupCard({required this.summary, required this.allWallets});
  // null opens the groups overview
  final WalletGroupSummary? summary;
  final AllWallets allWallets;

  @override
  Widget build(BuildContext context) {
    WalletGroupSummary? summary = this.summary;
    return Container(
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadiusDirectional.circular(15),
        boxShadow: boxShadowCheck(boxShadowGeneral(context)),
      ),
      child: OpenContainerNavigation(
        borderRadius: 15,
        closedColor: getColor(context, "lightDarkAccentHeavyLight"),
        openPage: summary == null
            ? AccountGroupsPage()
            : WalletGroupPage(groupPk: summary.group?.pk),
        onClosed: () => homePageStateKey.currentState?.refreshState(),
        button: (openContainer) {
          return Tappable(
            color: getColor(context, "lightDarkAccentHeavyLight"),
            borderRadius: 15,
            onTap: openContainer,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16, vertical: 13),
              child: summary == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Symbols.folder_copy_rounded,
                          fill: 1,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        SizedBox(height: 4),
                        TextFont(
                          text: "all-groups".tr(),
                          fontSize: 14,
                          textColor: getColor(context, "textLight"),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            WalletGroupIcon(group: summary.group, size: 18),
                            SizedBox(width: 10),
                            TextFont(
                              text: summary.name,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        showTotalsPerCurrency() && summary.totals.length > 1
                            ? CurrencyTotalsText(
                                allWallets: allWallets,
                                totals: summary.totals,
                                fontSize: 17,
                                autoSize: false,
                              )
                            : TextFont(
                                text: formatTotals(allWallets, summary.totals),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                        TextFont(
                          text: summary.walletsWithDetails.length.toString() +
                              " " +
                              (summary.walletsWithDetails.length == 1
                                  ? "account".tr().toLowerCase()
                                  : "accounts".tr().toLowerCase()),
                          fontSize: 13,
                          textColor: getColor(context, "textLight"),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
