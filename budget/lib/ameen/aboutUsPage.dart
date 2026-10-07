import 'dart:math';

import 'package:budget/ameen/brand.dart';
import 'package:budget/colors.dart';
import 'package:budget/functions.dart';
import 'package:budget/main.dart';
import 'package:budget/pages/aboutPage.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/debugPage.dart';
import 'package:budget/struct/languageMap.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/moreIcons.dart';
import 'package:budget/widgets/navigationSidebar.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/ratingPopup.dart';
import 'package:budget/widgets/showChangelog.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Ameen's "About us" page. The original upstream About page (credits,
// translators, graphics) stays reachable from the "Based on Cashew" card.
class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Color containerColor = appStateSettings["materialYou"]
        ? dynamicPastel(
            context, Theme.of(context).colorScheme.secondaryContainer,
            amountLight: 0.2, amountDark: 0.6)
        : getColor(context, "lightDarkAccent");
    double borderRadius = getPlatform() == PlatformOS.isIOS ? 10 : 15;

    return PageFramework(
      dragDownToDismiss: true,
      title: "about-us".tr(),
      getExtraHorizontalPadding: (context) {
        double maxWidth = 700;
        double widthOfScreen = MediaQuery.sizeOf(context).width -
            getWidthNavigationSidebar(context);
        return enableDoubleColumn(context)
            ? max(0, (widthOfScreen - maxWidth) / 2)
            : getHorizontalPaddingConstrained(context);
      },
      listWidgets: [
        Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: 15, vertical: 7),
          child: _AppInformation(),
        ),
        SizedBox(height: 5),
        _AboutUsLinks(containerColor: containerColor),
        SizedBox(height: 10),
        HorizontalBreak(),
        SizedBox(height: 10),
        Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: 15, vertical: 5),
          child: Tappable(
            onTap: () => openUrl('mailto:' + ameenContactEmail),
            onLongPress: () => copyToClipboard(ameenContactEmail),
            color: containerColor,
            borderRadius: borderRadius,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 13, vertical: 15),
              child: Column(
                children: [
                  TextFont(
                    text: "lead-developer".tr(),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                  ),
                  TextFont(
                    text: ameenDeveloperName,
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                    textColor: Theme.of(context).colorScheme.onPrimaryContainer,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                  ),
                  TextFont(
                    text: ameenContactEmail,
                    fontSize: 16,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    textColor: getColor(context, "textLight"),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 10),
        HorizontalBreak(),
        SizedBox(height: 10),
        _BasedOnUpstreamCard(
          containerColor: containerColor,
          borderRadius: borderRadius,
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

class _AppInformation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        Image(
          image: AssetImage("assets/icon/icon-small.png"),
          height: 70,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tappable(
              borderRadius: getPlatform() == PlatformOS.isIOS ? 10 : 15,
              onLongPress: () {
                if (allowDebugFlags) pushRoute(context, DebugPage());
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                    vertical: 3, horizontal: 10),
                child: TextFont(
                  text: globalAppName,
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  maxLines: 5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
              child: TextFont(
                text: getVersionString(),
                fontSize: 14,
                maxLines: 5,
              ),
            ),
          ],
        )
      ],
    );
  }
}

class _AboutUsLinks extends StatelessWidget {
  const _AboutUsLinks({required this.containerColor});
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    bool outlined = appStateSettings["outlinedIcons"] == true;
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 15, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          getPlatform() == PlatformOS.isIOS ? 10 : 15,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _linkRow(
              context,
              isExternalLink: true,
              onTap: () => openUrl(ameenWebsiteUrl),
              icon: outlined ? Icons.language_outlined : Icons.language_rounded,
              text: "website".tr(),
            ),
            const HorizontalBreak(padding: EdgeInsetsDirectional.zero),
            _linkRow(
              context,
              isExternalLink: true,
              onTap: () => openUrl(ameenGithubUrl),
              icon: MoreIcons.github,
              text: "app-is-open-source".tr(namedArgs: {"app": globalAppName}),
            ),
            const HorizontalBreak(padding: EdgeInsetsDirectional.zero),
            _linkRow(
              context,
              isExternalLink: true,
              onTap: () => openUrl(ameenFaqUrl),
              icon: outlined
                  ? Icons.live_help_outlined
                  : Icons.live_help_rounded,
              text: "guide-and-faq".tr(),
            ),
            const HorizontalBreak(padding: EdgeInsetsDirectional.zero),
            _linkRow(
              context,
              isExternalLink: false,
              onTap: () =>
                  openBottomSheet(context, RatingPopup(), fullSnap: true),
              icon: outlined
                  ? Icons.rate_review_outlined
                  : Icons.rate_review_rounded,
              text: "feedback".tr(),
            ),
            const HorizontalBreak(padding: EdgeInsetsDirectional.zero),
            _linkRow(
              context,
              isExternalLink: false,
              onTap: () => openOnBoarding(context),
              icon: outlined
                  ? Icons.door_front_door_outlined
                  : Icons.door_front_door_rounded,
              text: "view-app-intro".tr(),
            ),
            const HorizontalBreak(padding: EdgeInsetsDirectional.zero),
            _linkRow(
              context,
              isExternalLink: true,
              onTap: () => openUrl(ameenPrivacyPolicyUrl),
              icon: outlined ? Icons.policy_outlined : Icons.policy_rounded,
              text: "privacy-policy".tr(),
            ),
            const HorizontalBreak(padding: EdgeInsetsDirectional.zero),
            _linkRow(
              context,
              isExternalLink: false,
              onTap: () => openLicensesPage(context),
              icon: outlined
                  ? Icons.account_balance_outlined
                  : Icons.account_balance_rounded,
              text: "view-licenses-and-legalese".tr(),
            ),
            const HorizontalBreak(padding: EdgeInsetsDirectional.zero),
            _linkRow(
              context,
              isExternalLink: false,
              onTap: () => deleteAllDataFlow(context),
              icon: outlined
                  ? Icons.delete_sweep_outlined
                  : Icons.delete_sweep_rounded,
              text: "delete-all-data".tr(),
              color: Colors.red.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  // Same row style as AboutLinks in aboutPage.dart
  Widget _linkRow(
    BuildContext context, {
    required VoidCallback onTap,
    required IconData icon,
    required String text,
    required bool isExternalLink,
    Color? color,
  }) {
    bool outlined = appStateSettings["outlinedIcons"] == true;
    return Tappable(
      onTap: onTap,
      borderRadius: 0,
      color: color ?? containerColor,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
            start: 18, end: 18, top: 11, bottom: 11),
        child: Row(
          children: [
            Icon(
              icon,
              size: 25,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFont(
                text: text,
                fontSize: 17,
                maxLines: 5,
              ),
            ),
            Icon(
              isExternalLink
                  ? outlined
                      ? Icons.open_in_new_outlined
                      : Icons.open_in_new_rounded
                  : outlined
                      ? Icons.keyboard_arrow_right_outlined
                      : Icons.keyboard_arrow_right_rounded,
              size: 22,
              color: getColor(context, "black").withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BasedOnUpstreamCard extends StatelessWidget {
  const _BasedOnUpstreamCard(
      {required this.containerColor, required this.borderRadius});
  final Color containerColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    bool outlined = appStateSettings["outlinedIcons"] == true;
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 15, vertical: 5),
      child: Tappable(
        onTap: () => pushRoute(context, AboutPage()),
        color: containerColor,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Icon(
                outlined ? Icons.fork_right_outlined : Icons.fork_right_rounded,
                size: 30,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFont(
                      text: "based-on-app".tr(
                          namedArgs: {"upstream": upstreamAppName}),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      maxLines: 5,
                    ),
                    SizedBox(height: 3),
                    TextFont(
                      text: "based-on-app-description".tr(namedArgs: {
                        "app": globalAppName,
                        "upstream": upstreamAppName,
                        "author": upstreamAuthorName,
                      }),
                      fontSize: 14,
                      maxLines: 10,
                      textColor: getColor(context, "textLight"),
                    ),
                  ],
                ),
              ),
              Icon(
                outlined
                    ? Icons.keyboard_arrow_right_outlined
                    : Icons.keyboard_arrow_right_rounded,
                size: 22,
                color: getColor(context, "black").withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
