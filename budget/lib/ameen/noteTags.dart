// Hidden data Ameen keeps at the end of a transaction's note, so it is backed
// up and synced with the transaction without any database change.
//
//   "<note>\n<U+2063>⌖25.204849,55.270782|Dubai<U+2063>¤USD 20.00@3.672500"
//
// Each tag is the invisible separator U+2063, one symbol and a payload
// (no newlines, no U+2063). Users never see tags: notes are shown and edited
// without them.

// U+2063 INVISIBLE SEPARATOR, built from its code so the source stays readable
final String tagSeparator = String.fromCharCode(0x2063);
const String locationTag = "⌖";
const String foreignAmountTag = "¤";
const String baseRateTag = "≈";
const String transferTag = "⇄";

// Written in this order
const List<String> knownTags = [
  locationTag,
  foreignAmountTag,
  transferTag,
  baseRateTag,
];

final RegExp _tagBlock = RegExp(r"\n?((?:" +
    tagSeparator +
    "[^" +
    tagSeparator +
    r"\n]+)+)\s*$");

Map<String, String> ameenTagsOf(String? note) {
  Map<String, String> tags = {};
  if (note == null) return tags;
  RegExpMatch? match = _tagBlock.firstMatch(note);
  if (match == null) return tags;
  for (String part in match.group(1)!.split(tagSeparator)) {
    if (part.isEmpty) continue;
    String symbol = String.fromCharCode(part.runes.first);
    tags[symbol] = part.substring(symbol.length).trim();
  }
  return tags;
}

// The note as the user wrote it
String noteWithoutAmeenTags(String? note) {
  if (note == null) return "";
  return note.replaceFirst(_tagBlock, "");
}

String noteWithAmeenTags(String note, Map<String, String> tags) {
  String clean = noteWithoutAmeenTags(note);
  List<String> symbols = [
    ...knownTags.where(tags.containsKey),
    ...tags.keys.where((key) => !knownTags.contains(key)),
  ];
  String block = "";
  for (String symbol in symbols) {
    String payload =
        tags[symbol]!.replaceAll(tagSeparator, "").replaceAll("\n", " ").trim();
    if (payload == "") continue;
    block += tagSeparator + symbol + payload;
  }
  if (block == "") return clean;
  return clean + (clean == "" ? "" : "\n") + block;
}
