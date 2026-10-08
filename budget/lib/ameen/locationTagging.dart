import 'package:budget/ameen/noteTags.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

// Location tagging: the exact position where a transaction was added is kept
// in an invisible tag at the end of the transaction's note, so it is backed up
// and synced with the transaction and upstream's database is untouched.
// Only the city is ever shown.
//
//   "<note><U+2063>⌖25.204849,55.270782|Dubai"

const String locationTaggingSetting = "ameenLocationTagging";
final RegExp _locationPayload =
    RegExp(r"^(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)(?:\|(.*))?$");

class TransactionLocation {
  const TransactionLocation(this.latitude, this.longitude, this.city);
  final double latitude;
  final double longitude;
  final String? city;

  // Payload of the location tag (see noteTags.dart)
  String toPayload() =>
      latitude.toStringAsFixed(6) +
      "," +
      longitude.toStringAsFixed(6) +
      (city == null || city == "" ? "" : "|" + city!.replaceAll("|", " "));

  static TransactionLocation? fromPayload(String? payload) {
    if (payload == null) return null;
    RegExpMatch? match = _locationPayload.firstMatch(payload.trim());
    if (match == null) return null;
    double? lat = double.tryParse(match.group(1)!);
    double? lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    String? city = match.group(3);
    return TransactionLocation(lat, lng, city == "" ? null : city);
  }
}

bool locationTaggingEnabled() =>
    appStateSettings[locationTaggingSetting] != false;

TransactionLocation? locationOfNote(String? note) =>
    TransactionLocation.fromPayload(ameenTagsOf(note)[locationTag]);

// The note as the user wrote it (without any Ameen tags)
String noteWithoutLocation(String? note) => noteWithoutAmeenTags(note);

String noteWithLocation(String note, TransactionLocation? location) {
  Map<String, String> tags = ameenTagsOf(note);
  if (location == null) {
    tags.remove(locationTag);
  } else {
    tags[locationTag] = location.toPayload();
  }
  return noteWithAmeenTags(note, tags);
}

// Note preview for transaction lists: the note plus "📍 City"
String notePreviewWithCity(String? note) {
  String clean = noteWithoutAmeenTags(note).trim();
  String? city = locationOfNote(note)?.city;
  if (city == null) return clean;
  return clean == "" ? "📍 " + city : clean + "  ·  📍 " + city;
}

// Latest known position, refreshed in the background
TransactionLocation? _latest;
DateTime? _latestTime;
Future<TransactionLocation?>? _refreshing;

// App start: use what the phone already knows, never prompts for permission
Future warmUpLocation() async {
  if (!locationTaggingEnabled() || kIsWeb) return;
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) return;
    Position? position = await Geolocator.getLastKnownPosition();
    if (position != null) await _setLatest(position);
  } catch (e) {
    print("Location warm up failed: " + e.toString());
  }
}

// Add transaction opened: ask permission once, then get a fresh fix in the
// background so it is ready by the time the transaction is saved
void refreshLocationInBackground() {
  if (!locationTaggingEnabled()) return;
  _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
}

Future<TransactionLocation?> _refresh() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return _latest;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied &&
        appStateSettings["ameenLocationPermissionAsked"] != true) {
      await updateSettings("ameenLocationPermissionAsked", true,
          updateGlobalState: false);
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) return _latest;
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    );
    await _setLatest(position);
  } catch (e) {
    print("Location refresh failed: " + e.toString());
  }
  return _latest;
}

Future _setLatest(Position position) async {
  String? city = _latest?.city;
  // Only look the city up again after moving a few hundred metres
  if (_latest == null ||
      Geolocator.distanceBetween(_latest!.latitude, _latest!.longitude,
              position.latitude, position.longitude) >
          300) city = await _cityOf(position.latitude, position.longitude);
  _latest = TransactionLocation(position.latitude, position.longitude, city);
  _latestTime = DateTime.now();
}

Future<String?> _cityOf(double latitude, double longitude) async {
  if (kIsWeb) return null; // the platform geocoder is not available on web
  try {
    List<Placemark> places = await placemarkFromCoordinates(latitude, longitude);
    if (places.isEmpty) return null;
    Placemark place = places.first;
    for (String? candidate in [
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea
    ]) {
      if (candidate != null && candidate.trim() != "") return candidate.trim();
    }
  } catch (e) {
    print("City lookup failed: " + e.toString());
  }
  return null;
}

// Location to attach when saving a new transaction. Waits briefly for a fix
// in progress, otherwise uses the last one if it is recent.
Future<TransactionLocation?> locationForNewTransaction() async {
  if (!locationTaggingEnabled()) return null;
  if (_refreshing != null) {
    try {
      await _refreshing!.timeout(Duration(seconds: 2));
    } catch (_) {}
  }
  if (_latest == null || _latestTime == null) return null;
  if (DateTime.now().difference(_latestTime!) > Duration(minutes: 30))
    return null;
  return _latest;
}

class LocationTaggingSetting extends StatelessWidget {
  const LocationTaggingSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsContainerSwitch(
      title: "location-tagging".tr(),
      description: "location-tagging-description".tr(),
      initialValue: locationTaggingEnabled(),
      onSwitched: (value) async {
        await updateSettings(locationTaggingSetting, value,
            updateGlobalState: false);
        if (value) {
          await updateSettings("ameenLocationPermissionAsked", false,
              updateGlobalState: false);
          refreshLocationInBackground();
        }
      },
      icon: appStateSettings["outlinedIcons"]
          ? Icons.location_on_outlined
          : Icons.location_on_rounded,
    );
  }
}
