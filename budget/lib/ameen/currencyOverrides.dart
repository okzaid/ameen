// Ameen currency tweaks applied on top of upstream's generated currencies.json,
// so regenerating that file upstream never loses them.

// UAE Dirham sign (Unicode 17). The glyph is added to the bundled Inter fonts
// (the app wide fontFamilyFallback) by scripts/add_dirham_glyph.py
const String dirhamSign = "\u20C3";

const Map<String, String> ameenCurrencySymbols = {
  "aed": dirhamSign,
};

void applyAmeenCurrencyOverrides(Map<String, dynamic> currencies) {
  ameenCurrencySymbols.forEach((currencyKey, symbol) {
    if (currencies[currencyKey] is Map) {
      currencies[currencyKey]["Symbol"] = symbol;
    }
  });
}

// Native views (Android home screen widgets) can't use the app's fonts
String replaceSymbolsForNativeText(String text) {
  return text.replaceAll(dirhamSign, "AED ");
}
