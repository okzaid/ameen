import 'dart:convert';
import 'dart:ui' as ui;

import 'package:budget/ameen/walletGroups.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/colors.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Your own pictures as icons (bank logos, card photos, restaurant logos).
// The picture is cropped to a square, shrunk to 128 px and stored inside the
// existing iconName column as "img:<base64 png>", so it backs up and syncs
// with the category/account itself and needs no schema change.

const String photoIconPrefix = "img:";
const int photoIconSize = 128;

bool isPhotoIcon(String? iconName) =>
    iconName != null && iconName.startsWith(photoIconPrefix);

final Map<int, MemoryImage> _decoded = {};

// Decoded once per distinct picture
MemoryImage? photoIconImage(String iconName) {
  int key = iconName.hashCode;
  MemoryImage? cached = _decoded[key];
  if (cached != null) return cached;
  try {
    MemoryImage image = MemoryImage(
        base64Decode(iconName.substring(photoIconPrefix.length)));
    _decoded[key] = image;
    return image;
  } catch (e) {
    print("Bad photo icon: " + e.toString());
    return null;
  }
}

// Centre square crop, shrunk to photoIconSize, as a PNG
Future<Uint8List?> squarePhotoIconPng(Uint8List bytes) async {
  ui.Codec codec = await ui.instantiateImageCodec(bytes);
  ui.Image source = (await codec.getNextFrame()).image;
  double side = (source.width < source.height ? source.width : source.height)
      .toDouble();
  Rect sourceRect = Rect.fromLTWH((source.width - side) / 2,
      (source.height - side) / 2, side, side);
  ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas canvas = Canvas(recorder);
  canvas.drawImageRect(
    source,
    sourceRect,
    Rect.fromLTWH(0, 0, photoIconSize.toDouble(), photoIconSize.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  ui.Image result = await recorder
      .endRecording()
      .toImage(photoIconSize, photoIconSize);
  ByteData? data = await result.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

Future<String?> pickPhotoIcon(ImageSource source) async {
  try {
    XFile? file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return null;
    Uint8List? png = await squarePhotoIconPng(await file.readAsBytes());
    if (png == null) return null;
    return photoIconPrefix + base64Encode(png);
  } catch (e) {
    print("Could not pick photo icon: " + e.toString());
    return null;
  }
}

// Pictures already used anywhere, so a bank logo can be reused for every card
Future<List<String>> usedPhotoIcons() async {
  Set<String> found = {};
  void add(String? iconName) {
    if (isPhotoIcon(iconName)) found.add(iconName!);
  }

  for (TransactionCategory category
      in await database.getAllCategories(includeSubCategories: true))
    add(category.iconName);
  for (TransactionWallet wallet in await database.getAllWallets())
    add(wallet.iconName);
  for (Objective objective in await database.getAllObjectivesWithoutType())
    add(objective.iconName);
  for (WalletGroup group in getWalletGroups()) add(group.iconName);
  return found.toList();
}

class PhotoIcon extends StatelessWidget {
  const PhotoIcon({required this.iconName, required this.size, super.key});
  final String iconName;
  final double size;

  @override
  Widget build(BuildContext context) {
    MemoryImage? image = photoIconImage(iconName);
    if (image == null)
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.broken_image_rounded,
            size: size * 0.7, color: getColor(context, "textLight")),
      );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image(
        image: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
  }
}

// "Photo" tab of the icon picker
class PhotoIconPicker extends StatefulWidget {
  const PhotoIconPicker({
    required this.selectedImage,
    required this.onSelected,
    super.key,
  });
  final String? selectedImage;
  final Function(String iconName) onSelected;

  @override
  State<PhotoIconPicker> createState() => _PhotoIconPickerState();
}

class _PhotoIconPickerState extends State<PhotoIconPicker> {
  late Future<List<String>> used = usedPhotoIcons();
  bool loading = false;

  Future pick(ImageSource source) async {
    setState(() => loading = true);
    String? iconName = await pickPhotoIcon(source);
    if (mounted) setState(() => loading = false);
    if (iconName != null) widget.onSelected(iconName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _PickButton(
                  icon: Icons.photo_library_rounded,
                  label: "photo-from-gallery".tr(),
                  onTap: () => pick(ImageSource.gallery),
                ),
              ),
              if (kIsWeb == false) ...[
                SizedBox(width: 10),
                Expanded(
                  child: _PickButton(
                    icon: Icons.photo_camera_rounded,
                    label: "photo-from-camera".tr(),
                    onTap: () => pick(ImageSource.camera),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (loading)
          Padding(
            padding: const EdgeInsetsDirectional.all(10),
            child: CircularProgressIndicator(),
          ),
        FutureBuilder<List<String>>(
          future: used,
          builder: (context, snapshot) {
            List<String> photos = snapshot.data ?? [];
            if (photos.isEmpty)
              return Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: TextFont(
                  text: "photo-icons-hint".tr(),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  fontSize: 14,
                  textColor: getColor(context, "textLight"),
                ),
              );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                      start: 10, top: 10, bottom: 4),
                  child: TextFont(
                    text: "your-photos".tr(),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    textColor: getColor(context, "textLight"),
                  ),
                ),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      for (String photo in photos)
                        Padding(
                          padding: const EdgeInsetsDirectional.all(5),
                          child: Tappable(
                            borderRadius: 14,
                            onTap: () => widget.onSelected(photo),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  width: 2,
                                  color: widget.selectedImage == photo
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                ),
                              ),
                              padding: const EdgeInsetsDirectional.all(2),
                              child: PhotoIcon(iconName: photo, size: 51),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: 15,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon,
                color: Theme.of(context).colorScheme.onSecondaryContainer),
            SizedBox(height: 4),
            TextFont(text: label, fontSize: 14),
          ],
        ),
      ),
    );
  }
}
