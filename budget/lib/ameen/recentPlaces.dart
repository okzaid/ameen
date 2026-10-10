import 'package:budget/ameen/locationTagging.dart';
import 'package:budget/ameen/noteTags.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:drift/drift.dart' show OrderingTerm, StringExpressionOperators;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

// Recent places, suggested when typing or renaming a place. Kept in settings
// as {"old town": {"n": "Old Town", "t": "2026-10-10T…Z"}} so devices merge
// name by name when syncing; the newest 20 are shown.

const String recentPlacesSetting = "ameenRecentPlaces";
const int recentPlacesShown = 20;
const int _recentPlacesKept = 60;

String _key(String name) => name.trim().toLowerCase();

Map<String, dynamic> _stored([Map<String, dynamic>? settings]) {
  dynamic value = (settings ?? appStateSettings)[recentPlacesSetting];
  return value is Map ? Map<String, dynamic>.from(value) : {};
}

DateTime _time(dynamic entry) =>
    (entry is Map ? DateTime.tryParse(entry["t"]?.toString() ?? "") : null) ??
    DateTime(0);

// Newest first
List<String> recentPlaces() {
  List<MapEntry<String, dynamic>> entries = _stored()
      .entries
      .where((e) => e.value is Map && (e.value["n"] ?? "") != "")
      .toList()
    ..sort((a, b) => _time(b.value).compareTo(_time(a.value)));
  return [
    for (MapEntry<String, dynamic> e in entries.take(recentPlacesShown))
      e.value["n"].toString()
  ];
}

// Recent places containing [query] (case-insensitive), newest first
List<String> recentPlacesMatching(String query) {
  String q = query.trim().toLowerCase();
  List<String> places = recentPlaces();
  if (q == "") return places;
  return places
      .where((p) => p.toLowerCase().contains(q) && p.toLowerCase() != q)
      .toList();
}

Map<String, dynamic> _withPlace(
    Map<String, dynamic> places, String name, DateTime time) {
  String key = _key(name);
  dynamic current = places[key];
  if (current is Map && !_time(current).isBefore(time)) return places;
  places[key] = {"n": name.trim(), "t": time.toUtc().toIso8601String()};
  // Keep the list small: drop the oldest beyond the limit
  if (places.length > _recentPlacesKept) {
    List<String> oldest = places.keys.toList()
      ..sort((a, b) => _time(places[a]).compareTo(_time(places[b])));
    for (String k in oldest.take(places.length - _recentPlacesKept))
      places.remove(k);
  }
  return places;
}

// Called when a transaction with a place is saved
Future rememberRecentPlace(String? name) async {
  if (name == null || name.trim() == "") return;
  Map<String, dynamic> places = _stored();
  dynamic current = places[_key(name)];
  // Already the newest entry with the same spelling: nothing to write
  if (current is Map &&
      current["n"] == name.trim() &&
      recentPlaces().firstOrNull == name.trim()) return;
  await updateSettings(
      recentPlacesSetting, _withPlace(places, name, DateTime.now()),
      updateGlobalState: false);
}

// Newest entry per name wins
Map<String, dynamic> mergeRecentPlaces(
    Map<String, dynamic> local, Map<String, dynamic> remote) {
  Map<String, dynamic> merged = Map<String, dynamic>.from(local);
  remote.forEach((key, entry) {
    if (entry is! Map || (entry["n"] ?? "") == "") return;
    if (_time(entry).isAfter(_time(merged[key]))) merged[key] = entry;
  });
  return merged;
}

Future mergeRecentPlacesFrom(Map<String, dynamic> remoteSettings) async {
  Map<String, dynamic> remote = _stored(remoteSettings);
  if (remote.isEmpty) return;
  Map<String, dynamic> local = _stored();
  Map<String, dynamic> merged = mergeRecentPlaces(local, remote);
  if (merged.toString() == local.toString()) return;
  await updateSettings(recentPlacesSetting, merged, updateGlobalState: false);
}

// Startup, once: fill the list from places already on transactions
Future seedRecentPlaces() async {
  if (appStateSettings[recentPlacesSetting] != null) return;
  try {
    List<Transaction> withPlace = await (database.select(database.transactions)
          ..where((t) => t.note.like("%" + tagSeparator + locationTag + "%"))
          ..orderBy([(t) => OrderingTerm.desc(t.dateCreated)])
          ..limit(500))
        .get();
    Map<String, dynamic> places = {};
    for (Transaction transaction in withPlace) {
      String? name = locationOfNote(transaction.note)?.city;
      if (name == null || places.containsKey(_key(name))) continue;
      places = _withPlace(places, name, transaction.dateCreated);
      if (places.length >= recentPlacesShown) break;
    }
    await updateSettings(recentPlacesSetting, places, updateGlobalState: false);
  } catch (e) {
    print("Could not seed recent places: " + e.toString());
  }
}

// Chips under the place input; [query] is what has been typed so far
class RecentPlaceChips extends StatelessWidget {
  const RecentPlaceChips({
    required this.query,
    required this.onSelected,
    super.key,
  });
  final ValueListenable<String> query;
  final Function(String place) onSelected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: query,
      builder: (context, typed, _) {
        List<String> places = recentPlacesMatching(typed);
        if (places.isEmpty) return SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: 4, bottom: 10),
          child: SelectChips<String>(
            items: places,
            getSelected: (_) => false,
            onSelected: onSelected,
            getLabel: (place) => place,
            wrapped: false,
          ),
        );
      },
    );
  }
}
