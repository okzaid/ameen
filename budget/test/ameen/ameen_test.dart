import 'package:budget/ameen/currencyOverrides.dart';
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
}
