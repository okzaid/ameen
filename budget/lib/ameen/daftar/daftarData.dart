import 'dart:async';

import 'package:budget/ameen/recentPlaces.dart';
import 'package:drift/drift.dart' show Value;

import 'package:budget/ameen/daftar/daftarModel.dart';
import 'package:budget/ameen/foreignAmount.dart';
import 'package:budget/ameen/locationTagging.dart';
import 'package:budget/ameen/noteTags.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/databaseGlobal.dart';

// The only part of Daftar that reads Cashew's database. If upstream changes
// its tables, this is the file to adapt.

DaftarType daftarTypeOf(Transaction transaction) {
  switch (transaction.type) {
    case TransactionSpecialType.upcoming:
      return DaftarType.upcoming;
    case TransactionSpecialType.subscription:
      return DaftarType.subscription;
    case TransactionSpecialType.repetitive:
      return DaftarType.repetitive;
    case TransactionSpecialType.credit:
      return DaftarType.lent;
    case TransactionSpecialType.debt:
      return DaftarType.borrowed;
    case null:
      break;
  }
  // Transfers and balance corrections use the special category "0"
  if (transaction.categoryFk == "0") return DaftarType.transfer;
  return transaction.income ? DaftarType.income : DaftarType.expense;
}

DaftarRow daftarRowOf(
  Transaction transaction,
  Map<String, TransactionCategory> categories,
  AllWallets wallets,
) {
  TransactionCategory? category = categories[transaction.categoryFk];
  TransactionCategory? subcategory = transaction.subCategoryFk == null
      ? null
      : categories[transaction.subCategoryFk];
  TransactionWallet? wallet = wallets.indexedByPk[transaction.walletFk];
  Map<String, String> tags = ameenTagsOf(transaction.note);
  TransactionLocation? location =
      TransactionLocation.fromPayload(tags[locationTag]);
  ForeignAmount? foreign = foreignAmountOf(tags);
  String place = location?.city ??
      (location != null && location.hasCoordinates
          ? location.latitude!.toStringAsFixed(4) +
              ", " +
              location.longitude!.toStringAsFixed(4)
          : "");
  return DaftarRow(
    transactionPk: transaction.transactionPk,
    date: transaction.dateCreated,
    title: transaction.name,
    categoryPk: transaction.categoryFk,
    categoryName: category?.name ?? "",
    subcategoryPk: transaction.subCategoryFk,
    subcategoryName: subcategory?.name ?? "",
    amount: transaction.amount,
    walletPk: transaction.walletFk,
    walletName: wallet?.name ?? "",
    currency: wallet?.currency,
    decimals: wallet?.decimals ?? 2,
    type: daftarTypeOf(transaction),
    paid: transaction.paid,
    note: noteWithoutAmeenTags(transaction.note).trim(),
    place: place,
    paidIn: foreign == null || foreign.currency == wallet?.currency
        ? ""
        : convertToMoney(wallets, foreign.amount,
            currencyKey: foreign.currency),
  );
}

// Every transaction, re-emitted when transactions or categories change
// (account names come from [wallets], refreshed by the page)
Stream<(List<Transaction>, Map<String, TransactionCategory>)>
    watchDaftarSource() {
  late StreamController<(List<Transaction>, Map<String, TransactionCategory>)>
      controller;
  List<Transaction>? transactions;
  Map<String, TransactionCategory>? categories;
  List<StreamSubscription> subscriptions = [];
  void emit() {
    if (transactions != null && categories != null)
      controller.add((transactions!, categories!));
  }

  controller = StreamController(
    onListen: () {
      subscriptions
          .add(database.select(database.transactions).watch().listen((value) {
        transactions = value;
        emit();
      }, onError: controller.addError));
      subscriptions.add(database.watchAllCategoriesIndexed().listen((value) {
        categories = value;
        emit();
      }, onError: controller.addError));
    },
    onCancel: () {
      for (StreamSubscription s in subscriptions) s.cancel();
    },
  );
  return controller.stream;
}

Future<Transaction?> daftarTransaction(String transactionPk) =>
    database.tryGetTransactionFromPk(transactionPk);

// ---- Editing (phase 2) -----------------------------------------------------

// How a row looks with its staged edits applied
DaftarRow daftarRowWithEdits(
  DaftarRow row,
  Map<DaftarColumn, Object?>? edits,
  Map<String, TransactionCategory> categories,
  AllWallets wallets,
) {
  if (edits == null || edits.isEmpty) return row;
  T pick<T>(DaftarColumn column, T original) =>
      edits.containsKey(column) ? edits[column] as T : original;
  String? categoryPk = pick<String?>(DaftarColumn.category, row.categoryPk);
  String? subcategoryPk =
      pick<String?>(DaftarColumn.subcategory, row.subcategoryPk);
  String walletPk = pick<String>(DaftarColumn.account, row.walletPk);
  TransactionWallet? wallet = wallets.indexedByPk[walletPk];
  double amount = pick<double>(DaftarColumn.amount, row.amount);
  DaftarType type = row.type;
  if (edits.containsKey(DaftarColumn.amount) &&
      (type == DaftarType.expense || type == DaftarType.income))
    type = amount > 0 ? DaftarType.income : DaftarType.expense;
  return DaftarRow(
    transactionPk: row.transactionPk,
    date: pick<DateTime>(DaftarColumn.date, row.date),
    title: pick<String>(DaftarColumn.title, row.title),
    categoryPk: categoryPk,
    categoryName: categories[categoryPk]?.name ?? row.categoryName,
    subcategoryPk: subcategoryPk,
    subcategoryName:
        subcategoryPk == null ? "" : categories[subcategoryPk]?.name ?? "",
    amount: amount,
    walletPk: walletPk,
    walletName: wallet?.name ?? row.walletName,
    currency: wallet?.currency ?? row.currency,
    decimals: wallet?.decimals ?? row.decimals,
    type: type,
    paid: pick<bool>(DaftarColumn.paid, row.paid),
    note: pick<String>(DaftarColumn.note, row.note),
    place: pick<String>(DaftarColumn.place, row.place),
    paidIn: row.paidIn,
  );
}

class DaftarSaveResult {
  DaftarSaveResult(this.saved, this.failed);
  final int saved;
  final List<String> failed; // transactionPks that could not be saved
}

// Writes staged edits through Cashew's own save (which also marks the
// transaction modified, so Drive sync carries it). Hidden note tags (place,
// paid-in, rates) are kept; a renamed place keeps its coordinates.
Future<DaftarSaveResult> saveDaftarEdits(DaftarEdits edits) async {
  int saved = 0;
  List<String> failed = [];
  for (MapEntry<String, Map<DaftarColumn, Object?>> entry in edits.entries) {
    Map<DaftarColumn, Object?> columns = entry.value;
    try {
      Transaction? original = await database.tryGetTransactionFromPk(entry.key);
      if (original == null) {
        failed.add(entry.key);
        continue;
      }
      Transaction updated = original;
      if (columns.containsKey(DaftarColumn.date))
        updated = updated.copyWith(
            dateCreated: columns[DaftarColumn.date] as DateTime);
      if (columns.containsKey(DaftarColumn.title))
        updated = updated.copyWith(name: columns[DaftarColumn.title] as String);
      if (columns.containsKey(DaftarColumn.category))
        updated = updated.copyWith(
            categoryFk: columns[DaftarColumn.category] as String);
      if (columns.containsKey(DaftarColumn.subcategory))
        updated = updated.copyWith(
            subCategoryFk: Value(columns[DaftarColumn.subcategory] as String?));
      if (columns.containsKey(DaftarColumn.amount)) {
        double amount = columns[DaftarColumn.amount] as double;
        updated = updated.copyWith(amount: amount, income: amount > 0);
      }
      if (columns.containsKey(DaftarColumn.account))
        updated =
            updated.copyWith(walletFk: columns[DaftarColumn.account] as String);
      if (columns.containsKey(DaftarColumn.paid))
        updated = updated.copyWith(paid: columns[DaftarColumn.paid] as bool);
      if (columns.containsKey(DaftarColumn.note) ||
          columns.containsKey(DaftarColumn.place)) {
        Map<String, String> tags = ameenTagsOf(original.note);
        String note = columns.containsKey(DaftarColumn.note)
            ? columns[DaftarColumn.note] as String
            : noteWithoutAmeenTags(original.note);
        if (columns.containsKey(DaftarColumn.place)) {
          String place = (columns[DaftarColumn.place] as String).trim();
          TransactionLocation? location =
              TransactionLocation.fromPayload(tags[locationTag]);
          if (place == "" && !(location?.hasCoordinates ?? false)) {
            tags.remove(locationTag);
          } else if (place == "") {
            tags[locationTag] = TransactionLocation(
                    location!.latitude, location.longitude, null)
                .toPayload();
          } else {
            tags[locationTag] = TransactionLocation(
                    location?.latitude, location?.longitude, place)
                .toPayload();
            await rememberRecentPlace(place);
          }
        }
        updated = updated.copyWith(note: noteWithAmeenTags(note, tags));
      }
      await database.createOrUpdateTransaction(updated,
          originalTransaction: original);
      saved++;
    } catch (e) {
      print("Daftar could not save " + entry.key + ": " + e.toString());
      failed.add(entry.key);
    }
  }
  return DaftarSaveResult(saved, failed);
}
