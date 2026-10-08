import 'package:budget/ameen/materialCategoryIcon.dart';
import 'package:budget/ameen/materialIconCatalog.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:budget/colors.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Pieces added to upstream's SelectCategoryImage picker: a toggle between
// Material Symbols and the original illustrated icons, and the Material grid.

enum IconSource { material, illustrations, photo }

IconSource initialIconSource(String? selectedImage) {
  String image = (selectedImage ?? "").replaceAll("assets/categories/", "");
  if (image.startsWith("img:")) return IconSource.photo;
  // An existing illustrated icon opens on its own tab, everything else on Material
  if (image != "" && image != "image.png" && !isMaterialIcon(image))
    return IconSource.illustrations;
  return IconSource.material;
}

class IconSourceSelector extends StatelessWidget {
  const IconSourceSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });
  final IconSource selected;
  final Function(IconSource) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 5),
      child: SelectChips<IconSource>(
        items: IconSource.values,
        wrapped: true,
        allowMultipleSelected: false,
        scrollablePositionedList: false,
        getSelected: (source) => source == selected,
        onSelected: onChanged,
        getLabel: (source) => source == IconSource.material
            ? "material-icons".tr()
            : source == IconSource.photo
                ? "photo-icons".tr()
                : "illustrated-icons".tr(),
      ),
    );
  }
}

class MaterialIconGrid extends StatelessWidget {
  const MaterialIconGrid({
    required this.searchTerm,
    required this.selectedImage,
    required this.onSelected,
    this.color,
    super.key,
  });
  final String searchTerm;
  final String? selectedImage;
  final Function(MaterialIconForCategory) onSelected;
  // Colour of the category/account being edited, previewed on every icon
  final Color? color;

  Widget _wrap(List<MaterialIconForCategory> icons) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          for (MaterialIconForCategory icon in icons)
            MaterialIconOption(
              icon: icon.icon,
              color: color,
              selected: selectedImage == materialIconNameToStore(icon.name),
              onTap: () => onSelected(icon),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (searchTerm.trim() != "") {
      List<MaterialIconForCategory> results = searchMaterialIcons(searchTerm);
      if (results.isEmpty)
        return Padding(
          padding: const EdgeInsetsDirectional.all(20),
          child: TextFont(
            text: "no-icons-found".tr(),
            textColor: getColor(context, "textLight"),
          ),
        );
      return _wrap(results);
    }
    // Browsing: one heading per section
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (MaterialIconSection section in materialIconSections) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(
                start: 10, end: 10, top: 14, bottom: 4),
            child: TextFont(
              text: ("icon-section-" + section.key).tr() ==
                      "icon-section-" + section.key
                  ? section.title
                  : ("icon-section-" + section.key).tr(),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              textColor: getColor(context, "textLight"),
            ),
          ),
          _wrap(section.icons),
        ],
      ],
    );
  }
}

// Same footprint as upstream's ImageIcon in selectCategoryImage.dart
class MaterialIconOption extends StatelessWidget {
  const MaterialIconOption({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
    this.size = 55,
    super.key,
  });
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    Color? previewColor = color;
    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      margin: EdgeInsetsDirectional.all(5),
      height: size,
      width: size,
      decoration: BoxDecoration(
        border: Border.all(
          color: selected
              ? (previewColor ?? Theme.of(context).colorScheme.primary)
                  .withOpacity(0.8)
              : Colors.transparent,
          width: selected ? 2 : 0,
        ),
        borderRadius: BorderRadiusDirectional.all(Radius.circular(500)),
      ),
      child: Tappable(
        // Same tinted background CategoryIcon draws for this colour
        color: previewColor == null
            ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5)
            : dynamicPastel(context, previewColor,
                amountLight: 0.55, amountDark: 0.35),
        onTap: onTap,
        borderRadius: 500,
        child: Center(
          child: Icon(
            icon,
            size: size * 0.52,
            fill: 1,
            color: previewColor == null
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : materialIconForeground(context, previewColor),
          ),
        ),
      ),
    );
  }
}
