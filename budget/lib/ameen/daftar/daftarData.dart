import 'dart:async';

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
