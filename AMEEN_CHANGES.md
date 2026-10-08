# Ameen changes to upstream Cashew

Ameen is a fork of [Cashew](https://github.com/jameskokoska/Cashew) by James Kokoska (GPL-3.0).
This file lists every place Ameen touches upstream code, so merging upstream
updates (`git fetch upstream && git merge upstream/main`) stays predictable.

## Rules
- New logic lives in new files: `budget/lib/ameen/`, `budget/assets/fonts/` (Ameen-only fonts), `site/`.
- Edits to upstream files are small hooks marked `// AMEEN` (Dart) or `AMEEN` comments.
- No database schema changes (upstream owns the drift schema version). Ameen data is
  stored in existing columns (`iconName` with an `ms:` prefix, `Wallets.iconName`)
  or in `appStateSettings` (keys prefixed with `ameen`).
- Dart package name (`budget`) and Kotlin package (`com.budget.tracker_app`) are unchanged;
  only the Android `applicationId` and iOS bundle id differ.
- Translations: upstream's `assets/translations/` is left untouched. Ameen strings and
  renames live in `assets/ameen/translation-overrides.json` and are applied when
  translations load (`lib/ameen/translationOverrides.dart`).

## When resolving a merge conflict
Keep upstream's version of the surrounding code and re-apply the `// AMEEN` line(s).

## Touched upstream files
| Area | File | What |
|---|---|---|
| Pro free | `lib/pages/premiumPage.dart` | `premiumPopupEnabled`/`tryStoreEnabled` = false; hide `PremiumBanner` |
| Brand | `lib/struct/languageMap.dart` | `globalAppName` |
| Brand | `lib/main.dart` | app title |
| Brand | `lib/struct/uploadAttachment.dart` | Drive attachments folder name |
| Brand | `lib/widgets/accountAndBackup.dart`, `exportCSV.dart`, `exportDB.dart`, `importCSV.dart` | file name prefix, web app / FAQ links |
| Brand | `lib/pages/settingsPage.dart`, `lib/widgets/ratingPopup.dart`, `lib/pages/accountsPage.dart` | FAQ / privacy links |
| Brand | `lib/pages/autoTransactionsPageEmail.dart` | hard-coded app name in a hint |
| Brand | `android/app/build.gradle` | `applicationId`; google-services plugin applied only when configured |
| Brand | `android/app/src/main/AndroidManifest.xml` | label, App Links host, BILLING permission removed |
| Brand | `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, `ios/Runner.xcodeproj/project.pbxproj` | display name, usage strings, bundle id, associated domain |
| Brand | `web/index.html`, `web/manifest.json` | title / meta |
| Brand | `lib/struct/languageMap.dart` | `AmeenTranslationLoader` applies Ameen's strings at load time |
| Brand | `pubspec.yaml` | `assets/ameen/` asset folder |
| About us | `lib/pages/settingsPage.dart`, `lib/widgets/navigationFramework.dart` | open `AboutUsPage` (`lib/ameen/aboutUsPage.dart`) instead of `AboutPage`; upstream About page is opened from the "Based on Cashew" card |
| AED sign | `lib/struct/currencyFunctions.dart` | `applyAmeenCurrencyOverrides` after loading currencies.json (`lib/ameen/currencyOverrides.dart`) |
| AED sign | `assets/fonts/Inter-Regular.ttf`, `Inter-Bold.ttf` | U+20C3 glyph added by `scripts/add_dirham_glyph.py`. If upstream updates these fonts: take theirs, re-run the script |
| Material icons | `lib/widgets/categoryIcon.dart` | `CacheCategoryIcon` renders `ms:` icons via `MaterialCategoryIcon`, optional `color` param |
| Material icons | `lib/widgets/pieChart.dart`, `lib/widgets/categoryEntry.dart` | pass `color` to `CacheCategoryIcon` |
| Material icons | `lib/widgets/selectCategoryImage.dart` | Icons / Illustrations toggle and Material grid (`lib/ameen/materialIconPicker.dart`) |
| Account icons | `lib/pages/addWalletPage.dart` | icon picker next to the name, saves `Wallets.iconName` (`lib/ameen/walletIcon.dart`) |
| Account icons | `lib/widgets/walletEntry.dart`, `lib/pages/editWalletsPage.dart` | show the account icon |
| Account icons | `lib/widgets/selectAmount.dart`, `lib/pages/transactionFilters.dart` | `getAvatar` on account chips |
| Per-currency totals | `lib/database/tables.dart` | `watchTotalWithCountOfWallet(convertToPrimary:)` optional param (default unchanged) |
| Per-currency totals | `lib/widgets/transactionsAmountBox.dart` | optional `currencyTotalsStream` (`lib/ameen/perCurrency.dart`) |
| Per-currency totals | `lib/pages/homePage/homePageNetWorth.dart`, `homePageAllSpendingSummary.dart` | pass `currencyTotalsStream` when the setting is on |
| Per-currency totals | `lib/widgets/util/checkWidgetLaunch.dart` | home screen widget text per currency, AED shown as text |
| Per-currency totals / groups | `lib/struct/defaultPreferences.dart` | `ameen*` setting defaults |
| Groups | `lib/pages/editWalletsPage.dart` | group/total headers around rows, group follows drag, settings entries |
| Groups | `lib/pages/addWalletPage.dart` | group chips, saved after the account (`lib/ameen/walletGroups.dart`) |
| CI | `.github/workflows/firebase-hosting-pull-request.yml` | upstream preview deploy only runs in the upstream repo |

Ameen-only CI: `.github/workflows/ci.yml` (analyze + `test/ameen`) and `.github/workflows/upstream-sync.yml` (weekly upstream merge PR).
| Icon | `android/.../res/mipmap-*`, `drawable/notification_icon_android2.png`, `ios/.../AppIcon.appiconset`, `web/icons`, `web/favicon.*`, `assets/icon/*` | Ameen icon (sources in `design/icon/`, colour `#0F5C4D`); `web/manifest.json` + `pubspec.yaml` theme colour |
| Build | `android/app/build.gradle` | release falls back to debug signing without key.properties |
| Text weight | `lib/widgets/textWidgets.dart` | `ameenFontWeight()` around TextFont weights (`lib/ameen/textWeight.dart`) |
| Text weight | `lib/pages/settingsPage.dart` | `TextWeightSetting()` under the font picker |
| Text weight | `lib/struct/defaultPreferences.dart`, `pubspec.yaml` | default font Metropolis, `ameenTextWeight: light`; Metropolis Light/Medium/SemiBold assets |
| Group view | `lib/pages/homePage/homePage.dart`, `lib/pages/editHomePage.dart` | "Account Groups" home section (`lib/ameen/accountGroupsPages.dart`) |
| Group view | `lib/struct/defaultPreferences.dart` | home section key + show settings |
| Group view | `lib/main.dart` | `migrateAmeenSettings()` adds the section to saved home layouts |
| Group view | `lib/pages/editWalletsPage.dart` | ⋮ "Group View" |
| Group view | `lib/pages/addWalletPage.dart` | `initialGroupPk` (Add Account from a group) |
| Icon picker | `lib/widgets/selectCategoryImage.dart` | optional `color` passed to the Material grid |
| Icon picker | `lib/pages/addCategoryPage.dart`, `addObjectivePage.dart`, `objectivePage.dart` | pass the selected colour to the picker |

The Material icon catalog is generated: edit `scripts/gen_icon_catalog.py` and run it with the path to `material_symbols_icons/lib/symbols.dart`.
| Fonts | `pubspec.yaml`, `lib/pages/settingsPage.dart` | Nunito, Outfit, Manrope, Urbanist (`ameenExtraFonts`), OFL licences shown on the licences page |
| Frequent accounts | `lib/pages/addTransactionPage.dart` | account chips filtered by `walletsForTransactionChips` (`lib/ameen/frequentWallets.dart`) |
| Frequent accounts | `lib/pages/addWalletPage.dart` | "Frequent Account" switch next to the group chips |
| Sync | `lib/struct/syncClient.dart` | `mergeAmeenSyncedSettings()` adopts newer groups/frequent accounts from other devices (`lib/ameen/settingsSync.dart`) |
| Note tags | `lib/pages/addTransactionPage.dart` | `ameenTags`: hidden note tags (location, foreign amount, transfer counterpart, base rate) read on open, written on save (`lib/ameen/noteTags.dart`); location fetch on open |
| Location | `lib/widgets/transactionEntry/transactionEntry.dart`, `transactionEntryNote.dart` | note preview without the tag, plus "📍 City" |
| Location | `lib/pages/settingsPage.dart`, `pubspec.yaml`, `AndroidManifest.xml`, `ios/Runner/Info.plist` | Location Tagging switch, geolocator + geocoding, location permissions |
| Photo icons | `lib/widgets/selectCategoryImage.dart` | "Photo" tab (`lib/ameen/photoIcons.dart`); stored as `img:<base64 png>` in `iconName` |
| Base currency | `lib/struct/currencyFunctions.dart` | `amountRatioToPrimaryCurrency` converts into `baseCurrencyOf()`; `getCurrencyString` defaults to it (`lib/ameen/baseCurrency.dart`) |
| Base currency | `lib/functions.dart` | `convertToMoney` without a currency uses the base currency and its decimals |
| Base currency | `homePageNetWorth.dart`, `walletDetailsPage.dart`, `transactionEntry.dart`, `addTransactionPage.dart` (2), `homePageWalletList.dart`, `exchangeRatesPage.dart` | converted totals labelled with the base currency instead of the primary account's |
| Base currency | `lib/pages/settingsPage.dart` | `BaseCurrencySetting` replaces `PrimaryCurrencySetting` |
| Foreign spend | `lib/pages/addTransactionPage.dart` | amount pad wrapped in `ForeignAmountPad` ("Paid in"), `ForeignAmountLine` under the amount, re-convert on account change (`lib/ameen/foreignAmount.dart`) |
| Native amounts | `lib/widgets/transactionEntry/transactionEntryAmount.dart` | `NativeTransactionAmount` when "Amounts in Account Currency" is on |
| Native amounts | `lib/pages/settingsPage.dart` | `NativeTransactionAmountsSetting` |
| Transfers | `lib/pages/addWalletPage.dart` | `TransferBalancePopup`: keeps the typed amount, sent/received from `transferAmounts`, "<account> receives …" row with an editable received amount, ⇄ counterpart + ≈ base-rate note tags (`lib/ameen/transfers.dart`) |
| Currency view | `lib/widgets/watchAllWallets.dart` | app-wide account list passed through `applyCurrencyLens` (only the viewed currency's accounts; index kept) (`lib/ameen/currencyLens.dart`) |
| Currency view | `lib/database/tables.dart` | `currencyLensFilter` in `onlyShowIfFollowsSearchFilters` (null filters) and `onlyShowTransactionBasedOnSearchQuery`; `currencyLensWalletFilter` in `watchAllWalletsWithDetails` for home sections |
| Currency view | `lib/pages/homePage/homePage.dart` | `CurrencyLensButton` next to the edit-home button (`SizedBox.shrink` → `Spacer`) |
| Currency view | `lib/pages/addTransactionPage.dart` | default account via `defaultWalletPkForLens` |
