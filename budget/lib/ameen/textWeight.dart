import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Global text weight: upstream asks for FontWeight.bold almost everywhere.
// Instead of changing every call, upstream's TextFont maps the requested
// weight through ameenFontWeight(), so one setting lightens the whole app.
//   regular: unchanged (upstream Cashew look)
//   light:   bold -> semi bold, semi bold -> medium
//   lighter: bold -> medium, normal -> light

const String textWeightSetting = "ameenTextWeight";
const List<String> textWeightOptions = ["regular", "light", "lighter"];

FontWeight ameenFontWeight(FontWeight? weight) {
  FontWeight requested = weight ?? FontWeight.normal;
  switch (appStateSettings[textWeightSetting]) {
    case "light":
      if (requested.index >= FontWeight.w700.index) return FontWeight.w600;
      if (requested == FontWeight.w600) return FontWeight.w500;
      return requested;
    case "lighter":
      if (requested.index >= FontWeight.w600.index) return FontWeight.w500;
      if (requested == FontWeight.w400) return FontWeight.w300;
      return requested;
    default:
      return requested;
  }
}

class TextWeightSetting extends StatelessWidget {
  const TextWeightSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsContainerDropdown(
      title: "text-weight".tr(),
      icon: appStateSettings["outlinedIcons"]
          ? Icons.format_bold_outlined
          : Icons.format_bold_rounded,
      items: textWeightOptions,
      initial: (appStateSettings[textWeightSetting] ?? "regular").toString(),
      getLabel: (value) => ("text-weight-" + value).tr(),
      onChanged: (value) async {
        await updateSettings(textWeightSetting, value,
            updateGlobalState: true);
      },
    );
  }
}
