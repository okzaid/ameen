# AMEEN: generates budget/lib/ameen/materialIconCatalog.dart from SECTIONS below.
# Existing labels/tags are kept from the current file; new icons get a label
# from their name. Names are validated against material_symbols_icons.
#   python scripts/gen_icon_catalog.py <path to material_symbols_icons symbols.dart>
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "budget", "lib", "ameen", "materialIconCatalog.dart")

SECTIONS = [
    ("money", "Money & Banking", """
account_balance account_balance_wallet wallet payments money attach_money currency_exchange credit_card credit_score
add_card contactless savings price_check receipt_long receipt request_quote sell local_atm atm point_of_sale paid
toll monetization_on universal_currency universal_currency_alt euro currency_pound currency_rupee currency_yen
currency_franc currency_lira currency_ruble currency_yuan currency_bitcoin send_money request_page swap_horiz sync_alt
account_balance_wallet price_change payment card_membership qr_code_2 qr_code_scanner barcode_scanner
autopay checkbook smart_card_reader credit_card_clock credit_card_heart credit_card_gear cards account_balance_wallet nest_found_savings barcode receipt_long price_check order_approve contract contract_edit approval_delegation
"""),
    ("invest", "Investing & Savings", """
trending_up trending_down show_chart candlestick_chart pie_chart donut_large bar_chart stacked_line_chart
analytics insights query_stats finance finance_chip diamond workspace_premium military_tech emoji_events
real_estate_agent apartment villa landscape forest agriculture solar_power oil_barrel gas_meter
area_chart bubble_chart chart_data multiline_chart ssid_chart stacked_bar_chart waterfall_chart pie_chart_filled finance_mode monitoring trending_flat money_bag gold_bar real_estate_agent warehouse business add_business
"""),
    ("income", "Income & Work", """
work business_center badge engineering construction handshake volunteer_activism redeem card_giftcard loyalty
percent payments arrow_downward arrow_upward celebration storefront store support_agent computer laptop_mac
design_services brush draw camera code terminal school groups person_add
business_chip team_dashboard work_history work_outline badge person_celebrate payments contract handshake volunteer_activism laptop_chromebook
"""),
    ("food", "Food & Drink", """
restaurant restaurant_menu lunch_dining dinner_dining breakfast_dining brunch_dining ramen_dining rice_bowl set_meal
kebab_dining local_pizza bakery_dining cake icecream cookie fastfood takeout_dining local_cafe coffee coffee_maker
emoji_food_beverage local_bar liquor wine_bar sports_bar local_drink water_bottle nutrition egg egg_alt grocery
local_grocery_store kitchen skillet outdoor_grill soup_kitchen cooking blender microwave food_bank tapas
local_dining dining no_food liquor nutrition cake_add icecream bento local_pizza lunch_dining kitchen fastfood egg grocery cookie flatware restaurant_menu hot_tub water_full
"""),
    ("shopping", "Shopping", """
shopping_cart shopping_bag shopping_basket local_mall storefront store local_convenience_store package_2 inventory_2
local_shipping checkroom apparel styler steps watch eyeglasses diamond face_retouching_natural redeem sell
loyalty local_offer new_releases shoppingmode deployed_code
shop shop_2 shopping_cart_checkout add_shopping_cart store_mall_directory trolley household_supplies personal_bag travel_luggage_and_bags toys_and_games featured_seasonal_and_gifts garden_cart pet_supplies
"""),
    ("personal", "Personal Care", """
content_cut spa soap sanitizer face face_2 face_3 face_4 self_care health_and_beauty dry_cleaning local_laundry_service
styler wc bathtub shower hot_tub
clean_hands laundry face_unlock medical_mask menstrual_health
"""),
    ("home", "Home & Bills", """
home house cottage apartment villa key bed weekend chair chair_alt table_restaurant light lightbulb lamp
bolt electric_bolt water_drop gas_meter propane_tank ac_unit heat mode_fan air thermostat wifi router smartphone
phone_in_talk sim_card tv live_tv subscriptions autorenew cloud mail security sensor_door doorbell
handyman construction plumbing format_paint cleaning_services mop yard potted_plant local_florist grass
roofing garage fence chair kitchen dishwasher_gen washing_machine
family_home house_siding house_with_shield home_repair_service home_improvement_and_tools home_and_garden home_storage home_work other_houses bedroom_baby bedroom_child bedroom_parent single_bed table_bar electric_meter electrical_services water_heater water_damage water_pump cleaning cleaning_bucket carpenter tools_power_drill tools_wrench tools_ladder service_toolbox outdoor_garden nightlight light_mode thermostat_carbon energy_savings_leaf wifi_home router tv_remote connected_tv home_speaker light_group local_phone deskphone mark_email_unread markunread_mailbox key_vertical
"""),
    ("transport", "Transport", """
directions_car local_gas_station ev_station local_parking local_taxi hail car_repair local_car_wash tire_repair
car_rental car_crash traffic two_wheeler pedal_bike electric_scooter scooter moped directions_bus train subway tram
directions_boat commute airport_shuttle electric_car electric_bike directions_walk directions_run toll
garage_home minor_crash
directions_car_filled directions_bus_filled directions_boat_filled directions_bike electric_moped electric_rickshaw bike_scooter car_tag taxi_alert speed_camera emoji_transportation transportation cable_car trolley_cable_car mode_of_travel local_shipping
"""),
    ("travel", "Travel", """
flight flight_takeoff flight_land luggage hotel king_bed beach_access travel_explore map tour id_card public
location_on explore houseboat cabin camping holiday_village pool attractions sailing
mosque church temple_hindu synagogue temple_buddhist
airplane_ticket flights_and_hotels flight_class card_travel carry_on_bag checked_bag travel local_hotel hotel_class beach_access location_home streetview
"""),
    ("health", "Health & Fitness", """
medical_services local_hospital stethoscope medication local_pharmacy vaccines dentistry visibility psychology
favorite monitor_heart healing emergency health_and_safety ecg_heart glucose blood_pressure pill
fitness_center exercise sports_gymnastics self_improvement directions_run pool sports_soccer sports_tennis
sports_cricket sports_basketball golf_course hiking sports_martial_arts sports_football sports_volleyball
sports_handball rowing surfing skateboarding snowboarding downhill_skiing
medical_information home_health health_metrics cardiology gastroenterology fitness_tracker wheelchair_pickup sports sports_baseball sports_golf sports_hockey sports_mma sports_motorsports sports_rugby sports_kabaddi sports_score run_circle barefoot
"""),
    ("fun", "Entertainment", """
movie theaters confirmation_number local_activity attractions celebration festival music_note headphones podcasts
sports_esports stadia_controller casino extension palette photo_camera piano menu_book auto_stories newspaper
park camping kayaking scuba_diving sailing nightlife theater_comedy mic radio album videogame_asset toys
local_movies movie_creation play_music library_music queue_music music_video playing_cards games gamepad party_mode theater_comedy event_seat local_activity tv_guide
"""),
    ("family", "Family & Pets", """
family_restroom child_care child_friendly toys elderly diversity_3 group person pets cruelty_free
baby_changing_station stroller crib school backpack cake celebration favorite
account_child family_home child_care bedroom_baby
"""),
    ("education", "Education", """
school backpack library_books history_edu science translate edit print menu_book auto_stories calculate
book book_2 cast_for_education co_present quiz
book_3 book_4 book_5 book_online collections_bookmark local_printshop person_book model_training
"""),
    ("tech", "Tech & Subscriptions", """
computer laptop_mac devices tablet_mac watch_screentime keyboard mouse headset_mic speaker videogame_asset memory
battery_charging_full cable code apps domain smart_toy cloud storage dns phone_iphone tv_gen
laptop laptop_windows phone_android phone smartphone_camera tablet_camera camera_alt video_camera_back sd_card sim_card security_key vpn_key passkey cloud_sync cloud_done wifi_password email alternate_email
"""),
    ("other", "Other", """
category more_horiz help star bookmark label flag rocket_launch lightbulb event calendar_month schedule alarm
warning emergency smoking_rooms local_post_office inventory_2 moving description assignment account_box
folder folder_copy gavel balance policy shield verified lock
calendar_today event_repeat event_upcoming event_available edit_calendar punch_clock watch_later bookmarks bookmark_heart bookmark_star lock_clock shield_person shield_with_heart pan_tool restore other_admission
"""),
]

symbols_path = sys.argv[1]
valid = set(re.findall(r"static const IconData ([a-z0-9_]+)_rounded\b",
                       open(symbols_path, encoding="utf-8").read()))

existing = {}
text = open(OUT, encoding="utf-8").read()
for m in re.finditer(r'_I\("([a-z0-9_]+)", Symbols\.[a-z0-9_]+, "([^"]*)", \[([^\]]*)\]\)', text):
    existing[m.group(1)] = (m.group(2), m.group(3))

seen = set()
missing = []
out_sections = []
for key, title, names in SECTIONS:
    entries = []
    for name in names.split():
        if name not in valid:
            missing.append(name)
            continue
        if name in seen:
            continue
        seen.add(name)
        label, tags = existing.get(name, (None, None))
        if label is None:
            label = name.replace("_", " ").title()
            tags = ", ".join(f'"{w}"' for w in name.split("_") if not w.isdigit())
        entries.append(f'    _I("{name}", Symbols.{name}_rounded, "{label}", [{tags}]),')
    out_sections.append((key, title, entries))

dropped = [n for n in existing if n not in seen]

header = text[: text.index("typedef _I = MaterialIconForCategory;")]
body = ["typedef _I = MaterialIconForCategory;", ""]
body.append("// Sections shown as headings in the picker, in this order")
body.append("const List<MaterialIconSection> materialIconSections = [")
for key, title, entries in out_sections:
    body.append(f'  MaterialIconSection("{key}", "{title}", [')
    body.extend(entries)
    body.append("  ]),")
body.append("];")
body.append("")
body.append("final List<MaterialIconForCategory> materialIconCatalog = [")
body.append("  for (MaterialIconSection section in materialIconSections) ...section.icons")
body.append("];")
open(OUT, "w", encoding="utf-8", newline="\n").write(header + "\n".join(body) + "\n")
print("icons:", len(seen), "sections:", len(out_sections))
print("skipped (not in package):", " ".join(sorted(set(missing))))
print("dropped from old catalog:", " ".join(dropped))
