import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/ameen/accountChoice.dart';
import 'package:budget/ameen/scopedCurrency.dart';
import 'package:budget/ameen/currencyLens.dart';
import 'package:budget/ameen/currencyOverrides.dart';
import 'package:budget/ameen/baseCurrency.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/ameen/frequentWallets.dart';
import 'package:budget/ameen/foreignAmount.dart';
import 'package:budget/ameen/noteTags.dart';
import 'package:budget/ameen/transfers.dart';
import 'package:budget/ameen/locationTagging.dart';
import 'package:budget/ameen/photoIcons.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Canvas, Paint, Rect, Color;
import 'package:budget/ameen/settingsSync.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/ameen/materialIconCatalog.dart';
import 'package:budget/ameen/perCurrency.dart';
import 'package:budget/ameen/translationOverrides.dart';
import 'package:budget/ameen/walletIcon.dart';
import 'package:flutter_test/flutter_test.dart';

class _Amount {
  _Amount(this.currency, this.amount, [this.decimals = 2]);
  final String? currency;
  final double amount;
  final int decimals;
}

void main() {
  group("Per-currency totals", () {
    test("sums each currency separately, in first-seen order", () {
      List<CurrencyTotal> totals = sumPerCurrency<_Amount>(
        [
          _Amount("aed", 100),
          _Amount("usd", 20),
          _Amount("aed", 50.5),
          _Amount("usd", -5, 3),
        ],
        getCurrency: (a) => a.currency,
        getAmount: (a) => a.amount,
        getDecimals: (a) => a.decimals,
      );
      expect(totals.map((t) => t.currency).toList(), ["aed", "usd"]);
      expect(totals[0].total, 150.5);
      expect(totals[1].total, 15);
      expect(totals[1].decimals, 3);
    });

    test("empty input gives no totals", () {
      expect(
        sumPerCurrency<_Amount>([],
            getCurrency: (a) => a.currency, getAmount: (a) => a.amount),
        isEmpty,
      );
    });
  });

  group("AED symbol", () {
    test("overrides the generated currency symbol", () {
      Map<String, dynamic> currencies = {
        "aed": {"Code": "AED", "Symbol": "د.إ"},
        "usd": {"Code": "USD", "Symbol": "\$"},
      };
      applyAmeenCurrencyOverrides(currencies);
      expect(currencies["aed"]["Symbol"], "\u20C3");
      expect(currencies["usd"]["Symbol"], "\$");
    });

    test("native text replaces the sign with AED", () {
      expect(replaceSymbolsForNativeText("\u20C31,200.00"), "AED 1,200.00");
    });
  });

  group("Material icons", () {
    test("catalog names are unique and resolvable", () {
      Set<String> names = {};
      for (MaterialIconForCategory icon in materialIconCatalog) {
        expect(names.add(icon.name), true, reason: icon.name);
        expect(materialIconFor(materialIconNameToStore(icon.name)), icon.icon);
      }
    });

    test("prefix detection", () {
      expect(isMaterialIcon("ms:savings"), true);
      expect(isMaterialIcon("cutlery.png"), false);
      expect(isMaterialIcon(null), false);
      expect(materialIconFor("ms:not_a_real_icon"), null);
    });

    test("search matches tags and names", () {
      expect(searchMaterialIcons("salik").map((i) => i.name), contains("toll"));
      expect(searchMaterialIcons("credit card").map((i) => i.name),
          contains("credit_card"));
      expect(searchMaterialIcons("").length, materialIconCatalog.length);
    });
  });

  group("Account icons", () {
    test("emoji, Material and image icons round trip", () {
      String? emoji = walletIconNameFrom(emoji: "🏦");
      expect(emoji, "emoji:🏦");
      expect(walletIconEmoji(emoji), "🏦");
      expect(walletIconImage(emoji), null);

      String? material = walletIconNameFrom(image: "ms:account_balance");
      expect(walletIconImage(material), "ms:account_balance");
      expect(walletIconEmoji(material), null);

      expect(walletIconNameFrom(), null);
      expect(walletIconImage(null), null);
    });
  });

  group("Translation overrides", () {
    Map<String, dynamic> overrides = {
      "*": {"shared": "Shared"},
      "en": {"about-us": "About Us", "primary-currency": "Base Currency"},
    };
    test("English gets new keys and the app name", () {
      Map<String, dynamic> en = applyAmeenTranslationOverrides(
          {"enjoying-cashew-question": "Enjoying Cashew?", "primary-currency": "Primary Currency"},
          "en",
          overrides);
      expect(en["enjoying-cashew-question"], "Enjoying Ameen?");
      expect(en["about-us"], "About Us");
      expect(en["primary-currency"], "Base Currency");
      expect(en["shared"], "Shared");
    });
    test("Other languages keep their own translations", () {
      Map<String, dynamic> de = applyAmeenTranslationOverrides(
          {"primary-currency": "Hauptwährung"}, "de", overrides);
      expect(de["primary-currency"], "Hauptwährung");
      expect(de.containsKey("about-us"), false);
    });
  });

  group("Frequent accounts", () {
    List<TransactionWallet> wallets = [
      for (int i = 0; i < 8; i++)
        TransactionWallet(
          walletPk: "w$i",
          name: "Account $i",
          dateCreated: DateTime(2026),
          order: i,
          decimals: 2,
        )
    ];
    List<String> pks(List<TransactionWallet> list) =>
        list.map((w) => w.walletPk).toList();

    test("shows everything without pins or with few accounts", () {
      appStateSettings[frequentWalletsSetting] = [];
      appStateSettings["selectedWalletPk"] = "w0";
      expect(walletsForTransactionChips(wallets,
              selectedWalletPk: "w0", canShowAll: true).length,
          8);
      appStateSettings[frequentWalletsSetting] = ["w2"];
      expect(walletsForTransactionChips(wallets.take(5).toList(),
              selectedWalletPk: "w0", canShowAll: true).length,
          5);
    });

    test("shows frequent and selected accounts in order, not the default", () {
      appStateSettings[frequentWalletsSetting] = ["w5", "w2"];
      appStateSettings["selectedWalletPk"] = "w0";
      expect(
          pks(walletsForTransactionChips(wallets,
              selectedWalletPk: "w7", canShowAll: true)),
          ["w2", "w5", "w7"]);
    });

    test("no filtering when there is no show-all button", () {
      appStateSettings[frequentWalletsSetting] = ["w5"];
      expect(walletsForTransactionChips(wallets,
              selectedWalletPk: "w0", canShowAll: false).length,
          8);
    });
  });

  group("Location tag", () {
    TransactionLocation dubai = TransactionLocation(25.2048493, 55.2707828, "Dubai");
    test("round trips and stays out of the visible note", () {
      String note = noteWithLocation("Lunch with team", dubai);
      expect(noteWithoutLocation(note), "Lunch with team");
      TransactionLocation? parsed = locationOfNote(note);
      expect(parsed!.latitude, closeTo(25.204849, 0.000001));
      expect(parsed.longitude, closeTo(55.270783, 0.000001));
      expect(parsed.city, "Dubai");
      expect(visibleNote(note), "Lunch with team");
      expect(hasVisibleNote(note), true);
    });
    test("empty note and no city", () {
      String note = noteWithLocation("", TransactionLocation(-33.86, 151.2, null));
      expect(noteWithoutLocation(note), "");
      expect(locationOfNote(note)!.city, null);
      expect(visibleNote(note), "");
      expect(hasVisibleNote(note), false);
    });
    test("a typed place is kept without coordinates", () {
      String note = noteWithLocation("Coffee", TransactionLocation(null, null, "Old Town"));
      TransactionLocation? parsed = locationOfNote(note);
      expect(parsed!.city, "Old Town");
      expect(parsed.hasCoordinates, false);
      expect(ameenTagsOf(note)[locationTag], "|Old Town");
      expect(visibleNote(note), "Coffee");
      expect(TransactionLocation.fromPayload("|"), null);
      expect(TransactionLocation.fromPayload(""), null);
    });
    test("re-saving replaces the tag instead of adding another", () {
      String once = noteWithLocation("Taxi", dubai);
      String twice = noteWithLocation(once, dubai);
      expect(twice, once);
      expect(noteWithLocation(once, null), "Taxi");
    });
    test("plain notes are untouched", () {
      expect(locationOfNote("Paid 25,50 at 10:30"), null);
      expect(noteWithoutLocation("Line one\nLine two"), "Line one\nLine two");
    });
  });

  group("Settings sync", () {
    test("adopts newer Ameen settings from another device", () {
      Map<String, dynamic> local = {
        ameenSyncedModifiedSetting: "2026-10-01T10:00:00.000Z",
        "ameenWalletGroups": [],
      };
      Map<String, dynamic> remote = {
        ameenSyncedModifiedSetting: "2026-10-02T10:00:00.000Z",
        "ameenWalletGroups": [{"pk": "g1", "name": "Banks"}],
        "ameenFrequentWallets": ["w1"],
        "font": "Avenir",
      };
      Map<String, dynamic>? newer = pickNewerAmeenSettings(local, remote);
      expect(newer!["ameenWalletGroups"], remote["ameenWalletGroups"]);
      expect(newer["ameenFrequentWallets"], ["w1"]);
      expect(newer.containsKey("font"), false);
    });
    test("keeps local settings when they are newer or the device never set any", () {
      Map<String, dynamic> local = {ameenSyncedModifiedSetting: "2026-10-03T10:00:00.000Z"};
      expect(pickNewerAmeenSettings(local, {ameenSyncedModifiedSetting: "2026-10-02T10:00:00.000Z"}), null);
      expect(pickNewerAmeenSettings(local, {"ameenWalletGroups": []}), null);
    });
  });

  group("Photo icons", () {
    testWidgets("crops to a 128 px square and round trips", (tester) async {
      await tester.runAsync(() async {
        // A 300x200 red/blue test picture
        ui.PictureRecorder recorder = ui.PictureRecorder();
        Canvas canvas = Canvas(recorder);
        canvas.drawRect(Rect.fromLTWH(0, 0, 150, 200), Paint()..color = Color(0xFFFF0000));
        canvas.drawRect(Rect.fromLTWH(150, 0, 150, 200), Paint()..color = Color(0xFF0000FF));
        ui.Image picture = await recorder.endRecording().toImage(300, 200);
        final bytes = (await picture.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

        final png = await squarePhotoIconPng(bytes);
        ui.Image result = (await (await ui.instantiateImageCodec(png!)).getNextFrame()).image;
        expect(result.width, photoIconSize);
        expect(result.height, photoIconSize);
        expect(png.length, lessThan(20000));
      });
    });
    test("prefix detection", () {
      expect(isPhotoIcon("img:AAAA"), true);
      expect(isPhotoIcon("ms:savings"), false);
      expect(isPhotoIcon(null), false);
    });
  });

  group("Base currency", () {
    TransactionWallet wallet(String pk, String currency) => TransactionWallet(
        walletPk: pk,
        name: pk,
        dateCreated: DateTime(2026),
        order: 0,
        decimals: 2,
        currency: currency);
    AllWallets allWallets = AllWallets(
      list: [wallet("inr", "inr"), wallet("aed", "aed")],
      indexedByPk: {"inr": wallet("inr", "inr"), "aed": wallet("aed", "aed")},
    );
    Map<String, dynamic> settings(String? base) => {
          "selectedWalletPk": "inr",
          baseCurrencySetting: base,
          "customCurrencyAmounts": {},
          // rates per 1 USD
          "cachedCurrencyExchange": {"usd": 1, "aed": 3.6725, "inr": 84.0},
        };

    test("unset follows the primary account (upstream behaviour)", () {
      expect(baseCurrencyOf(allWallets, settings(null)), "inr");
      expect(
          amountRatioToPrimaryCurrency(allWallets, "aed",
              appStateSettingsPassed: settings(null)),
          closeTo(84.0 / 3.6725, 1e-9));
    });

    test("set base converts into it, independent of the primary account", () {
      expect(baseCurrencyOf(allWallets, settings("aed")), "aed");
      expect(
          amountRatioToPrimaryCurrency(allWallets, "inr",
              appStateSettingsPassed: settings("aed")),
          closeTo(3.6725 / 84.0, 1e-9));
      expect(
          amountRatioToPrimaryCurrency(allWallets, "aed",
              appStateSettingsPassed: settings("aed")),
          1);
      // A base no account uses still converts
      expect(
          amountRatioToPrimaryCurrency(allWallets, "aed",
              appStateSettingsPassed: settings("usd")),
          closeTo(1 / 3.6725, 1e-9));
    });
  });

  group("Note tags", () {
    test("several tags round trip and stay hidden", () {
      String note = noteWithAmeenTags("Dinner", {
        baseRateTag: "AED>INR@22.730000",
        locationTag: "25.204849,55.270783|Dubai",
        foreignAmountTag: "USD 20.0@3.672500",
      });
      expect(noteWithoutAmeenTags(note), "Dinner");
      Map<String, String> tags = ameenTagsOf(note);
      expect(tags[locationTag], "25.204849,55.270783|Dubai");
      expect(tags[foreignAmountTag], "USD 20.0@3.672500");
      expect(tags[baseRateTag], "AED>INR@22.730000");
      expect(locationOfNote(note)!.city, "Dubai");
      expect(visibleNote(note), "Dinner");
    });
    test("older location-only notes still read", () {
      String old = "Taxi\n\u2063⌖25.204849,55.270783|Dubai";
      expect(locationOfNote(old)!.city, "Dubai");
      expect(noteWithoutAmeenTags(old), "Taxi");
    });
    test("empty tag set leaves the note alone", () {
      expect(noteWithAmeenTags("Just a note", {}), "Just a note");
      expect(noteWithAmeenTags("", {}), "");
    });
  });

  group("Foreign amount", () {
    test("payload, market charge, effective rate and fee", () {
      ForeignAmount usd = ForeignAmount("usd", 20, 3.6725);
      ForeignAmount parsed = ForeignAmount.fromPayload(usd.toPayload())!;
      expect(parsed.currency, "usd");
      expect(parsed.amount, 20);
      expect(parsed.marketRate, closeTo(3.6725, 1e-9));
      expect(usd.chargedAtMarket(2), 73.45);
      expect(usd.effectiveRate(74.55), closeTo(3.7275, 1e-9));
      expect(usd.feeFraction(74.55), closeTo(0.01497, 1e-4));
      expect(ForeignAmount.fromPayload("garbage"), null);
    });

    test("saving records the base rate and drops a same-currency original", () async {
      appStateSettings["ameenLocationTagging"] = false;
      appStateSettings["ameenBaseCurrency"] = "inr";
      appStateSettings["customCurrencyAmounts"] = {};
      appStateSettings["cachedCurrencyExchange"] = {"usd": 1, "aed": 3.6725, "inr": 84.0};
      AllWallets none = AllWallets(list: [], indexedByPk: {});
      Map<String, String> tags = await tagsForSave(
        tags: {foreignAmountTag: "USD 20.0@3.672500"},
        isNew: true,
        allWallets: none,
        walletCurrency: "aed",
      );
      expect(tags[baseRateTag], startsWith("AED>INR@22.87"));
      expect(tags[foreignAmountTag], "USD 20.0@3.672500");
      Map<String, String> same = await tagsForSave(
        tags: {foreignAmountTag: "USD 20.0@1.000000"},
        isNew: false,
        allWallets: none,
        walletCurrency: "usd",
      );
      expect(same.containsKey(foreignAmountTag), false);
      expect(same[baseRateTag], startsWith("USD>INR@84"));
    });

    test("a removed location stays removed and is not written", () async {
      appStateSettings["ameenLocationTagging"] = true;
      AllWallets none = AllWallets(list: [], indexedByPk: {});
      Map<String, String> tags = await tagsForSave(
        tags: {locationTag: ""},
        isNew: true,
        allWallets: none,
        walletCurrency: "aed",
      );
      expect(tags[locationTag], "");
      String note = noteWithAmeenTags("Taxi", tags);
      expect(locationOfNote(note), null);
      expect(visibleNote(note), "Taxi");
      appStateSettings["ameenLocationTagging"] = false;
    });

    test("changing the account re-converts the original", () {
      appStateSettings["customCurrencyAmounts"] = {};
      appStateSettings["cachedCurrencyExchange"] = {"usd": 1, "aed": 3.6725, "inr": 84.0};
      TransactionWallet inrWallet = TransactionWallet(
          walletPk: "i", name: "ICICI", dateCreated: DateTime(2026), order: 0,
          decimals: 2, currency: "inr");
      var (tags, charged) = reconvertForeignForWallet(
          {foreignAmountTag: "USD 20.0@3.672500"}, inrWallet);
      expect(charged, 1680.0);
      expect(ForeignAmount.fromPayload(tags[foreignAmountTag])!.marketRate, 84.0);
    });
  });

  group("Real-rate transfers", () {
    TransactionWallet w(String pk, String cur) => TransactionWallet(
        walletPk: pk, name: pk, dateCreated: DateTime(2026), order: 0,
        decimals: 2, currency: cur);
    TransactionWallet adcb = w("adcb", "aed");
    TransactionWallet icici = w("icici", "inr");
    setUp(() {
      appStateSettings["customCurrencyAmounts"] = {};
      appStateSettings["cachedCurrencyExchange"] = {"usd": 1, "aed": 3.6725, "inr": 84.0};
      appStateSettings["ameenBaseCurrency"] = "aed";
    });

    test("market amounts by default, signs like upstream", () {
      TransferAmounts t = transferAmounts(
          entered: 1000, enteredCurrency: "aed", from: adcb, to: icici);
      expect(t.from, -1000);
      expect(t.to, 22872.70);
      TransferAmounts back = transferAmounts(
          entered: -1000, enteredCurrency: "aed", from: adcb, to: icici);
      expect(back.from, 1000);
      expect(back.to, -22872.70);
    });

    test("typed received amount wins, only for the same pair", () {
      ReceivedOverride got = ReceivedOverride("adcb", "icici", 22600);
      expect(transferAmounts(entered: 1000, enteredCurrency: "aed",
              from: adcb, to: icici, received: got).to, 22600);
      expect(transferAmounts(entered: 1000, enteredCurrency: "aed",
              from: icici, to: adcb, received: got).to, isNot(22600));
    });

    test("each side records the other side's amount", () {
      AllWallets all = AllWallets(list: [adcb, icici],
          indexedByPk: {"adcb": adcb, "icici": icici});
      String note = transferNote(note: "Transferred Balance", self: adcb,
          other: icici, otherAmount: 22600, allWallets: all);
      expect(noteWithoutAmeenTags(note), "Transferred Balance");
      expect(ameenTagsOf(note)[transferTag], "INR 22600.00");
      expect(transferCounterpartText(all, note), startsWith("⇄ "));
    });
  });

  group("Currency view", () {
    TransactionWallet w(String pk, String cur) => TransactionWallet(
        walletPk: pk, name: pk, dateCreated: DateTime(2026), order: 0,
        decimals: 2, currency: cur);
    List<TransactionWallet> wallets = [
      w("adcb", "aed"), w("icici", "inr"), w("hdfc", "inr")
    ];
    AllWallets all = AllWallets(
        list: wallets, indexedByPk: {for (var x in wallets) x.walletPk: x});
    tearDown(() {
      appStateSettings[currencyLensSetting] = "";
      applyCurrencyLens(all);
    });

    test("All keeps every account and the chosen base", () {
      appStateSettings[currencyLensSetting] = "";
      appStateSettings["ameenBaseCurrency"] = "aed";
      AllWallets shown = applyCurrencyLens(all);
      expect(shown.list.length, 3);
      expect(lensWalletPks, isNull);
      expect(baseCurrencyOf(shown), "aed");
    });

    test("one currency: only its accounts, shown in it, index kept", () {
      appStateSettings[currencyLensSetting] = "inr";
      appStateSettings["ameenBaseCurrency"] = "aed";
      AllWallets shown = applyCurrencyLens(all);
      expect(shown.list.map((x) => x.walletPk), ["icici", "hdfc"]);
      expect(shown.indexedByPk.length, 3);
      expect(lensWalletPks, {"icici", "hdfc"});
      expect(baseCurrencyOf(shown), "inr");
      expect(chosenBaseCurrency(shown), "aed");
      expect(amountRatioToPrimaryCurrency(shown, "inr"), 1);
    });

    test("new transactions: no account unless the view has only one", () {
      appStateSettings[currencyLensSetting] = "inr";
      applyCurrencyLens(all);
      expect(initialAccountForNewTransaction(), noAccountChosen);
      appStateSettings[currencyLensSetting] = "aed";
      applyCurrencyLens(all);
      expect(initialAccountForNewTransaction(), "adcb");
      appStateSettings[currencyLensSetting] = "";
      applyCurrencyLens(all);
      expect(initialAccountForNewTransaction(), noAccountChosen);
    });

    test("a currency with no accounts falls back to All", () {
      appStateSettings[currencyLensSetting] = "usd";
      AllWallets shown = applyCurrencyLens(all);
      expect(shown.list.length, 3);
      expect(activeCurrencyLens, isNull);
    });
  });

  group("Budgets and goals in their own currency", () {
    TransactionWallet w(String pk, String cur) => TransactionWallet(
        walletPk: pk, name: pk, dateCreated: DateTime(2026), order: 0,
        decimals: 2, currency: cur);
    List<TransactionWallet> wallets = [
      w("adcb", "aed"), w("icici", "inr"), w("hdfc", "inr")
    ];
    AllWallets all = AllWallets(
        list: wallets, indexedByPk: {for (var x in wallets) x.walletPk: x});
    setUp(() {
      appStateSettings[currencyLensSetting] = "";
      applyCurrencyLens(all);
      appStateSettings["customCurrencyAmounts"] = {};
      appStateSettings["cachedCurrencyExchange"] = {"usd": 1, "aed": 3.6725, "inr": 84.0};
      appStateSettings["ameenBaseCurrency"] = "aed";
    });

    test("inside a scope totals convert into the budget's currency", () {
      ScopedWallets scoped = ScopedWallets(all, "inr");
      expect(baseCurrencyOf(scoped), "inr");
      expect(amountRatioToPrimaryCurrency(scoped, "inr"), 1);
      expect(amountRatioToPrimaryCurrency(scoped, "aed"), closeTo(84 / 3.6725, 1e-9));
      // Converted into base and back is exact for the budget's own currency
      double viaBase = 1234.5 * amountRatioToPrimaryCurrency(all, "inr");
      expect(viaBase * amountRatioToPrimaryCurrency(scoped, "aed"), closeTo(1234.5, 1e-9));
    });

    test("only-currency accounts are detected in any order", () {
      expect(walletPksOfCurrency(all, "inr"), ["icici", "hdfc"]);
      expect(isOnlyCurrencyAccounts(all, "inr", ["hdfc", "icici"]), true);
      expect(isOnlyCurrencyAccounts(all, "inr", ["icici"]), false);
      expect(isOnlyCurrencyAccounts(all, "inr", null), false);
      expect(isOnlyCurrencyAccounts(all, "inr", ["icici", "hdfc", "adcb"]), false);
    });
  });

  group("Title accounts", () {
    TransactionWallet w(String pk, String cur) => TransactionWallet(
        walletPk: pk, name: pk, dateCreated: DateTime(2026), order: 0,
        decimals: 2, currency: cur);
    List<TransactionWallet> wallets = [w("adcb", "aed"), w("icici", "inr")];
    AllWallets all = AllWallets(
        list: wallets, indexedByPk: {for (var x in wallets) x.walletPk: x});
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      appStateSettings[currencyLensSetting] = "";
      applyCurrencyLens(all);
      appStateSettings["autoAddAssociatedTitles"] = true;
      appStateSettings[titleAccountsSetting] = {};
    });

    test("remembers the account per title, any case", () async {
      await rememberTitleAccount("Lulu ", "icici");
      expect(accountForTitle("lulu"), "icici");
      expect(accountForTitle("LULU"), "icici");
      expect(accountForTitle("Carrefour"), isNull);
      await rememberTitleAccount("Lulu", "adcb");
      expect(accountForTitle("Lulu"), "adcb");
    });

    test("deleted accounts and other currency views are ignored", () async {
      await rememberTitleAccount("Taxi", "gone");
      expect(accountForTitle("Taxi"), isNull);
      await rememberTitleAccount("Lulu", "icici");
      appStateSettings[currencyLensSetting] = "aed";
      applyCurrencyLens(all);
      expect(accountForTitle("Lulu"), isNull);
    });

    test("sync keeps the newest entry per title", () {
      Map<String, dynamic> local = {
        "lulu": {"w": "icici", "t": "2026-10-01T00:00:00Z"},
        "taxi": {"w": "adcb", "t": "2026-10-05T00:00:00Z"},
      };
      Map<String, dynamic> remote = {
        "lulu": {"w": "adcb", "t": "2026-10-03T00:00:00Z"},
        "taxi": {"w": "icici", "t": "2026-10-02T00:00:00Z"},
        "cafe": {"w": "icici", "t": "2026-10-02T00:00:00Z"},
      };
      Map<String, dynamic> merged = mergeTitleAccounts(local, remote);
      expect(merged["lulu"]["w"], "adcb");
      expect(merged["taxi"]["w"], "adcb");
      expect(merged["cafe"]["w"], "icici");
    });
  });
}
