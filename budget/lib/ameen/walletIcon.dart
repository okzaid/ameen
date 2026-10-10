import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/addCategoryPage.dart';
import 'package:budget/widgets/categoryIcon.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/selectCategoryImage.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Account (wallet) icons, stored in the existing (previously unused)
// Wallets.iconName column:
//   "ms:<name>"     Material Symbols icon (see materialIconCatalog.dart)
//   "emoji:<emoji>" an emoji
//   "<file>.png"    one of upstream's illustrated category icons

const String walletEmojiPrefix = "emoji:";

String? walletIconImage(String? iconName) {
  if (iconName == null || iconName == "") return null;
  if (iconName.startsWith(walletEmojiPrefix)) return null;
  return iconName;
}

String? walletIconEmoji(String? iconName) {
  if (iconName == null || !iconName.startsWith(walletEmojiPrefix)) return null;
  return iconName.substring(walletEmojiPrefix.length);
}

String? walletIconNameFrom({String? image, String? emoji}) {
  if (emoji != null && emoji != "") return walletEmojiPrefix + emoji;
  if (image != null && image != "") return image;
  return null;
}

bool walletHasIcon(TransactionWallet wallet) =>
    walletIconImage(wallet.iconName) != null ||
    walletIconEmoji(wallet.iconName) != null;

// A bare icon (no background) for account rows and cards
class WalletIcon extends StatelessWidget {
  const WalletIcon({required this.wallet, this.size = 22, super.key});
  final TransactionWallet wallet;
  final double size;

  @override
  Widget build(BuildContext context) {
    String? emoji = walletIconEmoji(wallet.iconName);
    String? image = walletIconImage(wallet.iconName);
    if (emoji != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: TextFont(
              text: emoji,
              fontSize: size * 0.8,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (image != null) {
      return CacheCategoryIcon(
        iconName: image,
        size: size,
        color: HexColor(wallet.colour,
            defaultColor: Theme.of(context).colorScheme.primary),
      );
    }
    return SizedBox.shrink();
  }
}

// The tappable icon next to the account name on the add/edit account page.
// Reuses upstream's IconPreview and SelectCategoryImage picker.
class WalletIconPicker extends StatelessWidget {
  const WalletIconPicker({
    required this.iconName,
    required this.color,
    required this.onChanged,
    super.key,
  });
  final String? iconName;
  final Color? color;
  final Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    String? image = walletIconImage(iconName);
    String? emoji = walletIconEmoji(iconName);
    return Tappable(
      color: Colors.transparent,
      borderRadius: 15,
      onTap: () {
        openBottomSheet(
          context,
          PopupFramework(
            title: "select-icon".tr(),
            child: SelectCategoryImage(
              color: color,
              selectedImage:
                  image == null ? null : "assets/categories/" + image,
              setSelectedImage: (String? selected) {
                onChanged(walletIconNameFrom(
                    image: (selected ?? "")
                        .replaceFirst("assets/categories/", "")));
              },
              setSelectedEmoji: (String? selected) {
                onChanged(walletIconNameFrom(emoji: selected));
              },
              // Account names are never suggested from an icon
              setSelectedTitle: (_) {},
            ),
          ),
          showScrollbar: true,
        );
      },
      onLongPress: iconName == null ? null : () => onChanged(null),
      child: image == null && emoji == null
          ? _EmptyWalletIcon(color: color)
          : IconPreview(
              selectedImage: image,
              selectedEmoji: emoji,
              selectedColor: color,
              smallPreview: true,
            ),
    );
  }
}

class _EmptyWalletIcon extends StatelessWidget {
  const _EmptyWalletIcon({required this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      alignment: AlignmentDirectional.center,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: dynamicPastel(
              context, color ?? Theme.of(context).colorScheme.primary,
              amountLight: 0.55, amountDark: 0.35),
          borderRadius: BorderRadiusDirectional.circular(15),
        ),
        child: Icon(
          Icons.add_photo_alternate_rounded,
          size: 26,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

// For SelectChips(getAvatar:) on account pickers. Only used when at least one
// account has an icon, accounts without one show their colour as a dot.
Widget Function(TransactionWallet)? walletChipAvatarBuilder(
    List<TransactionWallet> wallets) {
  if (wallets.any(walletHasIcon) == false) return null;
  return (TransactionWallet wallet) {
    return LayoutBuilder(builder: (context, constraints) {
      if (walletHasIcon(wallet))
        return WalletIcon(wallet: wallet, size: constraints.maxWidth);
      return Center(
        child: Container(
          width: constraints.maxWidth * 0.6,
          height: constraints.maxWidth * 0.6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HexColor(wallet.colour,
                    defaultColor: Theme.of(context).colorScheme.primary)
                .withOpacity(0.7),
          ),
        ),
      );
    });
  };
}
