import 'package:budget/ameen/materialIconCatalog.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Pieces added to upstream's SelectCategoryImage picker: a toggle between
// Material Symbols and the original illustrated icons, and the Material grid.

enum IconSource { material, illustrations }

IconSource initialIconSource(String? selectedImage) {
  String image = (selectedImage ?? "").replaceAll("assets/categories/", "");
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
    super.key,
  });
  final String searchTerm;
  final String? selectedImage;
  final Function(MaterialIconForCategory) onSelected;

  @override
  Widget build(BuildContext context) {
    List<MaterialIconForCategory> icons = searchMaterialIcons(searchTerm);
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          for (MaterialIconForCategory icon in icons)
            MaterialIconOption(
              icon: icon.icon,
              selected: selectedImage == materialIconNameToStore(icon.name),
              onTap: () => onSelected(icon),
            ),
        ],
      ),
    );
  }
}

// Same footprint as upstream's ImageIcon in selectCategoryImage.dart
class MaterialIconOption extends StatelessWidget {
  const MaterialIconOption({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.size = 55,
    super.key,
  });
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      margin: EdgeInsetsDirectional.all(5),
      height: size,
      width: size,
      decoration: BoxDecoration(
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
              : Colors.transparent,
          width: selected ? 2 : 0,
        ),
        borderRadius: BorderRadiusDirectional.all(Radius.circular(500)),
      ),
      child: Tappable(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        onTap: onTap,
        borderRadius: 500,
        child: Center(
          child: Icon(
            icon,
            size: size * 0.52,
            fill: 1,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
