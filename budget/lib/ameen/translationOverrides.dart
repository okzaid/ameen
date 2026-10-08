import 'dart:convert';

import 'package:budget/struct/languageMap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Ameen's text changes are applied when translations load, so upstream's
// generated translation files stay untouched and never conflict on merge.
//  1. The upstream app name in any string becomes Ameen's.
//  2. assets/ameen/translation-overrides.json is merged on top:
//     {"*": {...every language}, "en": {...}, "<lang>": {...}}
//     English (the fallback language) gets every key, other languages only
//     override keys they already translate.

const String _upstreamAppName = "Cashew";
const String _appName = "Ameen";
const String _overridesPath = "assets/ameen/translation-overrides.json";

Map<String, dynamic>? _overridesCache;

Future<Map<String, dynamic>> _loadOverrides() async {
  return _overridesCache ??=
      json.decode(await rootBundle.loadString(_overridesPath));
}

class AmeenTranslationLoader extends RootBundleAssetLoaderCustomLocaleLoader {
  const AmeenTranslationLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    Map<String, dynamic>? translations = await super.load(path, locale);
    if (translations == null) return null;
    String file = getLocalePath(path, locale).split("/").last;
    String lang = file.replaceAll(".json", "");
    return applyAmeenTranslationOverrides(
        translations, lang, await _loadOverrides());
  }
}

Map<String, dynamic> applyAmeenTranslationOverrides(
  Map<String, dynamic> translations,
  String lang,
  Map<String, dynamic> overrides,
) {
  Map<String, dynamic> result = {};
  translations.forEach((key, value) {
    result[key] =
        value is String ? value.replaceAll(_upstreamAppName, _appName) : value;
  });
  bool isBaseLanguage = lang == "en" || lang == "none";
  Map<String, dynamic> all = Map<String, dynamic>.from(overrides["*"] ?? {});
  all.forEach((key, value) {
    if (isBaseLanguage || result.containsKey(key)) result[key] = value;
  });
  Map<String, dynamic> forLang =
      Map<String, dynamic>.from(overrides[lang] ?? {});
  if (lang == "none") forLang = Map<String, dynamic>.from(overrides["en"] ?? {});
  forLang.forEach((key, value) {
    if (isBaseLanguage || result.containsKey(key)) result[key] = value;
  });
  return result;
}
