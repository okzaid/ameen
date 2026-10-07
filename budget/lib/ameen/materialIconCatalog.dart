import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Material Symbols (Rounded) icons that can be picked for categories, goals and
// accounts, next to upstream's PNG icons and emoji.
//
// Stored in the existing iconName columns as "ms:<name>", so no database schema
// change is needed. Icons are referenced as consts so icon tree shaking still
// only bundles the glyphs listed here.

const String materialIconPrefix = "ms:";

bool isMaterialIcon(String? iconName) =>
    iconName != null && iconName.startsWith(materialIconPrefix);

String materialIconNameToStore(String name) => materialIconPrefix + name;

IconData? materialIconFor(String? iconName) {
  if (iconName == null) return null;
  String name = iconName.startsWith(materialIconPrefix)
      ? iconName.substring(materialIconPrefix.length)
      : iconName;
  return materialIconsByName[name]?.icon;
}

class MaterialIconForCategory {
  const MaterialIconForCategory(
      this.name, this.icon, this.mostLikelyCategoryName, this.tags);
  final String name;
  final IconData icon;
  final String mostLikelyCategoryName;
  final List<String> tags;
}

final Map<String, MaterialIconForCategory> materialIconsByName = {
  for (MaterialIconForCategory entry in materialIconCatalog) entry.name: entry
};

List<MaterialIconForCategory> searchMaterialIcons(String search) {
  String query = search.trim().toLowerCase();
  if (query == "") return materialIconCatalog;
  return materialIconCatalog.where((entry) {
    if (entry.name.replaceAll("_", " ").contains(query)) return true;
    if (entry.mostLikelyCategoryName.toLowerCase().contains(query)) return true;
    for (String tag in entry.tags) {
      if (tag.contains(query)) return true;
    }
    return false;
  }).toList();
}

typedef _I = MaterialIconForCategory;

const List<MaterialIconForCategory> materialIconCatalog = [
  // Money and accounts
  _I("account_balance", Symbols.account_balance_rounded, "Bank", ["bank", "account", "building"]),
  _I("account_balance_wallet", Symbols.account_balance_wallet_rounded, "Wallet", ["wallet", "cash", "account"]),
  _I("wallet", Symbols.wallet_rounded, "Wallet", ["wallet", "purse", "cash"]),
  _I("payments", Symbols.payments_rounded, "Cash", ["cash", "money", "notes", "bills"]),
  _I("money", Symbols.money_rounded, "Cash", ["cash", "money", "notes"]),
  _I("attach_money", Symbols.attach_money_rounded, "Money", ["dollar", "money", "income"]),
  _I("currency_exchange", Symbols.currency_exchange_rounded, "Exchange", ["exchange", "forex", "transfer"]),
  _I("credit_card", Symbols.credit_card_rounded, "Credit Card", ["card", "credit", "visa", "mastercard"]),
  _I("credit_score", Symbols.credit_score_rounded, "Credit", ["credit", "score", "card"]),
  _I("add_card", Symbols.add_card_rounded, "Card", ["card", "debit", "new"]),
  _I("contactless", Symbols.contactless_rounded, "Tap to Pay", ["contactless", "nfc", "tap", "pay"]),
  _I("savings", Symbols.savings_rounded, "Savings", ["savings", "piggy", "bank", "save"]),
  _I("price_check", Symbols.price_check_rounded, "Bills", ["price", "check", "paid"]),
  _I("receipt_long", Symbols.receipt_long_rounded, "Bills", ["receipt", "bill", "invoice"]),
  _I("request_quote", Symbols.request_quote_rounded, "Quote", ["quote", "invoice", "document"]),
  _I("sell", Symbols.sell_rounded, "Sales", ["sale", "tag", "price"]),
  _I("local_atm", Symbols.local_atm_rounded, "ATM", ["atm", "cash", "withdraw"]),
  _I("atm", Symbols.atm_rounded, "ATM", ["atm", "cash", "withdraw"]),
  _I("point_of_sale", Symbols.point_of_sale_rounded, "Shop", ["pos", "register", "checkout"]),
  _I("paid", Symbols.paid_rounded, "Paid", ["paid", "coin", "money"]),
  _I("toll", Symbols.toll_rounded, "Tolls", ["toll", "coins", "salik"]),
  _I("monetization_on", Symbols.monetization_on_rounded, "Income", ["income", "coin", "money"]),
  _I("universal_currency_alt", Symbols.universal_currency_alt_rounded, "Currency", ["currency", "money"]),
  _I("trending_up", Symbols.trending_up_rounded, "Investments", ["invest", "stocks", "growth"]),
  _I("show_chart", Symbols.show_chart_rounded, "Stocks", ["stocks", "chart", "market"]),
  _I("candlestick_chart", Symbols.candlestick_chart_rounded, "Trading", ["trading", "stocks", "crypto"]),
  _I("pie_chart", Symbols.pie_chart_rounded, "Portfolio", ["portfolio", "chart"]),
  _I("currency_bitcoin", Symbols.currency_bitcoin_rounded, "Crypto", ["bitcoin", "crypto"]),
  _I("diamond", Symbols.diamond_rounded, "Valuables", ["diamond", "jewelry", "luxury"]),
  _I("workspace_premium", Symbols.workspace_premium_rounded, "Gold", ["gold", "premium", "badge"]),
  _I("handshake", Symbols.handshake_rounded, "Loans", ["loan", "deal", "lend", "debt"]),
  _I("volunteer_activism", Symbols.volunteer_activism_rounded, "Charity", ["charity", "donation", "zakat", "sadaqah", "give"]),
  _I("redeem", Symbols.redeem_rounded, "Gifts", ["gift", "redeem", "voucher"]),
  _I("card_giftcard", Symbols.card_giftcard_rounded, "Gift Cards", ["gift", "card", "voucher"]),
  _I("loyalty", Symbols.loyalty_rounded, "Rewards", ["loyalty", "points", "rewards"]),
  _I("percent", Symbols.percent_rounded, "Interest", ["interest", "percent", "rate"]),
  _I("request_page", Symbols.request_page_rounded, "Statements", ["statement", "page"]),
  _I("work", Symbols.work_rounded, "Salary", ["salary", "work", "job", "income"]),
  _I("business_center", Symbols.business_center_rounded, "Business", ["business", "work"]),
  _I("badge", Symbols.badge_rounded, "Freelance", ["freelance", "id", "work"]),
  _I("real_estate_agent", Symbols.real_estate_agent_rounded, "Rent Income", ["rent", "property", "real estate"]),
  _I("gavel", Symbols.gavel_rounded, "Legal", ["legal", "lawyer", "court", "fine"]),
  _I("balance", Symbols.balance_rounded, "Tax", ["tax", "balance", "law"]),
  _I("policy", Symbols.policy_rounded, "Insurance", ["insurance", "policy"]),
  _I("health_and_safety", Symbols.health_and_safety_rounded, "Insurance", ["insurance", "health", "safety"]),
  _I("shield", Symbols.shield_rounded, "Protection", ["insurance", "shield"]),

  // Food and drink
  _I("restaurant", Symbols.restaurant_rounded, "Dining", ["food", "restaurant", "eat", "dining"]),
  _I("lunch_dining", Symbols.lunch_dining_rounded, "Fast Food", ["burger", "lunch", "food"]),
  _I("dinner_dining", Symbols.dinner_dining_rounded, "Dinner", ["dinner", "pasta", "food"]),
  _I("breakfast_dining", Symbols.breakfast_dining_rounded, "Breakfast", ["breakfast", "bread", "food"]),
  _I("brunch_dining", Symbols.brunch_dining_rounded, "Brunch", ["brunch", "food"]),
  _I("ramen_dining", Symbols.ramen_dining_rounded, "Asian Food", ["ramen", "noodles", "food"]),
  _I("rice_bowl", Symbols.rice_bowl_rounded, "Rice", ["rice", "bowl", "food"]),
  _I("set_meal", Symbols.set_meal_rounded, "Seafood", ["fish", "seafood", "meal"]),
  _I("kebab_dining", Symbols.kebab_dining_rounded, "Kebab", ["kebab", "shawarma", "grill"]),
  _I("local_pizza", Symbols.local_pizza_rounded, "Pizza", ["pizza", "food"]),
  _I("bakery_dining", Symbols.bakery_dining_rounded, "Bakery", ["bakery", "bread", "pastry"]),
  _I("cake", Symbols.cake_rounded, "Desserts", ["cake", "dessert", "birthday"]),
  _I("icecream", Symbols.icecream_rounded, "Ice Cream", ["ice cream", "dessert"]),
  _I("cookie", Symbols.cookie_rounded, "Snacks", ["cookie", "snack"]),
  _I("fastfood", Symbols.fastfood_rounded, "Fast Food", ["fast food", "burger", "fries"]),
  _I("takeout_dining", Symbols.takeout_dining_rounded, "Takeout", ["takeout", "delivery", "food"]),
  _I("scooter", Symbols.scooter_rounded, "Food Delivery", ["delivery", "talabat", "deliveroo", "scooter"]),
  _I("local_cafe", Symbols.local_cafe_rounded, "Coffee", ["coffee", "cafe", "tea"]),
  _I("coffee", Symbols.coffee_rounded, "Coffee", ["coffee", "cup"]),
  _I("emoji_food_beverage", Symbols.emoji_food_beverage_rounded, "Tea", ["tea", "karak", "drink"]),
  _I("local_bar", Symbols.local_bar_rounded, "Drinks", ["drinks", "bar", "cocktail"]),
  _I("local_drink", Symbols.local_drink_rounded, "Water", ["water", "drink"]),
  _I("water_bottle", Symbols.water_bottle_rounded, "Water", ["water", "bottle"]),
  _I("nutrition", Symbols.nutrition_rounded, "Fruits", ["fruit", "nutrition", "healthy"]),
  _I("egg", Symbols.egg_rounded, "Groceries", ["egg", "groceries"]),
  _I("grocery", Symbols.grocery_rounded, "Groceries", ["grocery", "vegetables", "supermarket"]),
  _I("local_grocery_store", Symbols.local_grocery_store_rounded, "Groceries", ["grocery", "cart", "supermarket"]),
  _I("kitchen", Symbols.kitchen_rounded, "Kitchen", ["kitchen", "fridge"]),
  _I("skillet", Symbols.skillet_rounded, "Cooking", ["cooking", "pan", "kitchen"]),
  _I("outdoor_grill", Symbols.outdoor_grill_rounded, "BBQ", ["bbq", "grill"]),

  // Shopping
  _I("shopping_cart", Symbols.shopping_cart_rounded, "Shopping", ["shopping", "cart", "buy"]),
  _I("shopping_bag", Symbols.shopping_bag_rounded, "Shopping", ["shopping", "bag", "mall"]),
  _I("shopping_basket", Symbols.shopping_basket_rounded, "Shopping", ["basket", "shopping"]),
  _I("local_mall", Symbols.local_mall_rounded, "Mall", ["mall", "shopping"]),
  _I("storefront", Symbols.storefront_rounded, "Stores", ["store", "shop", "market"]),
  _I("store", Symbols.store_rounded, "Stores", ["store", "shop"]),
  _I("local_convenience_store", Symbols.local_convenience_store_rounded, "Convenience Store", ["convenience", "store", "baqala"]),
  _I("package_2", Symbols.package_2_rounded, "Online Orders", ["package", "amazon", "noon", "parcel", "online"]),
  _I("local_shipping", Symbols.local_shipping_rounded, "Shipping", ["shipping", "delivery", "truck"]),
  _I("checkroom", Symbols.checkroom_rounded, "Clothing", ["clothes", "clothing", "fashion"]),
  _I("apparel", Symbols.apparel_rounded, "Clothing", ["clothes", "shirt", "fashion"]),
  _I("styler", Symbols.styler_rounded, "Laundry", ["laundry", "dry cleaning", "clothes"]),
  _I("local_laundry_service", Symbols.local_laundry_service_rounded, "Laundry", ["laundry", "washing"]),
  _I("steps", Symbols.steps_rounded, "Shoes", ["shoes", "footwear"]),
  _I("watch", Symbols.watch_rounded, "Watches", ["watch", "accessories"]),
  _I("eyeglasses", Symbols.eyeglasses_rounded, "Glasses", ["glasses", "optical"]),
  _I("face_retouching_natural", Symbols.face_retouching_natural_rounded, "Beauty", ["beauty", "makeup", "cosmetics"]),
  _I("content_cut", Symbols.content_cut_rounded, "Haircut", ["haircut", "barber", "salon"]),
  _I("spa", Symbols.spa_rounded, "Spa", ["spa", "massage", "relax"]),
  _I("soap", Symbols.soap_rounded, "Toiletries", ["soap", "toiletries", "hygiene"]),
  _I("sanitizer", Symbols.sanitizer_rounded, "Personal Care", ["sanitizer", "care"]),
  _I("weekend", Symbols.weekend_rounded, "Furniture", ["furniture", "sofa", "home"]),
  _I("chair", Symbols.chair_rounded, "Furniture", ["chair", "furniture"]),
  _I("bed", Symbols.bed_rounded, "Bedroom", ["bed", "furniture"]),
  _I("light", Symbols.light_rounded, "Lighting", ["lamp", "light"]),
  _I("yard", Symbols.yard_rounded, "Garden", ["garden", "plants", "yard"]),
  _I("potted_plant", Symbols.potted_plant_rounded, "Plants", ["plant", "garden"]),
  _I("local_florist", Symbols.local_florist_rounded, "Flowers", ["flowers", "florist"]),
  _I("handyman", Symbols.handyman_rounded, "Repairs", ["repair", "tools", "maintenance"]),
  _I("construction", Symbols.construction_rounded, "Construction", ["construction", "renovation"]),
  _I("plumbing", Symbols.plumbing_rounded, "Plumbing", ["plumbing", "repair"]),
  _I("format_paint", Symbols.format_paint_rounded, "Painting", ["paint", "decor"]),
  _I("cleaning_services", Symbols.cleaning_services_rounded, "Cleaning", ["cleaning", "maid", "housekeeping"]),
  _I("mop", Symbols.mop_rounded, "Cleaning", ["mop", "cleaning"]),

  // Home and bills
  _I("home", Symbols.home_rounded, "Home", ["home", "house", "rent"]),
  _I("house", Symbols.house_rounded, "House", ["house", "home"]),
  _I("apartment", Symbols.apartment_rounded, "Rent", ["rent", "apartment", "flat", "building"]),
  _I("villa", Symbols.villa_rounded, "Villa", ["villa", "house"]),
  _I("key", Symbols.key_rounded, "Rent", ["key", "rent", "lease"]),
  _I("bolt", Symbols.bolt_rounded, "Electricity", ["electricity", "power", "dewa", "utilities"]),
  _I("electric_bolt", Symbols.electric_bolt_rounded, "Electricity", ["electricity", "power"]),
  _I("water_drop", Symbols.water_drop_rounded, "Water Bill", ["water", "utilities"]),
  _I("gas_meter", Symbols.gas_meter_rounded, "Gas", ["gas", "utilities"]),
  _I("propane_tank", Symbols.propane_tank_rounded, "Gas Cylinder", ["gas", "cylinder", "cooking"]),
  _I("ac_unit", Symbols.ac_unit_rounded, "Cooling", ["ac", "cooling", "empower", "chiller"]),
  _I("heat", Symbols.heat_rounded, "Heating", ["heating"]),
  _I("wifi", Symbols.wifi_rounded, "Internet", ["internet", "wifi", "broadband"]),
  _I("router", Symbols.router_rounded, "Internet", ["router", "internet"]),
  _I("smartphone", Symbols.smartphone_rounded, "Phone", ["phone", "mobile", "du", "etisalat", "e&"]),
  _I("phone_in_talk", Symbols.phone_in_talk_rounded, "Phone Bill", ["phone", "call"]),
  _I("sim_card", Symbols.sim_card_rounded, "Mobile Plan", ["sim", "mobile", "recharge"]),
  _I("tv", Symbols.tv_rounded, "TV", ["tv", "television"]),
  _I("live_tv", Symbols.live_tv_rounded, "Streaming", ["streaming", "netflix", "tv"]),
  _I("subscriptions", Symbols.subscriptions_rounded, "Subscriptions", ["subscriptions", "streaming"]),
  _I("autorenew", Symbols.autorenew_rounded, "Recurring", ["recurring", "renew", "subscription"]),
  _I("cloud", Symbols.cloud_rounded, "Cloud Storage", ["cloud", "storage", "icloud", "google one"]),
  _I("mail", Symbols.mail_rounded, "Post", ["mail", "post", "letter"]),
  _I("security", Symbols.security_rounded, "Security", ["security", "alarm"]),
  _I("pets", Symbols.pets_rounded, "Pets", ["pets", "dog", "cat"]),
  _I("cruelty_free", Symbols.cruelty_free_rounded, "Pets", ["pets", "rabbit"]),
  _I("child_care", Symbols.child_care_rounded, "Childcare", ["child", "baby", "nanny"]),
  _I("child_friendly", Symbols.child_friendly_rounded, "Baby", ["baby", "stroller"]),
  _I("toys", Symbols.toys_rounded, "Toys", ["toys", "kids"]),
  _I("family_restroom", Symbols.family_restroom_rounded, "Family", ["family", "kids"]),
  _I("elderly", Symbols.elderly_rounded, "Parents", ["parents", "elderly", "family"]),
  _I("diversity_3", Symbols.diversity_3_rounded, "Friends", ["friends", "people", "social"]),
  _I("group", Symbols.group_rounded, "Shared", ["group", "shared", "split"]),
  _I("person", Symbols.person_rounded, "Personal", ["personal", "person", "me"]),
  _I("support_agent", Symbols.support_agent_rounded, "Services", ["service", "support", "helper"]),

  // Transport
  _I("directions_car", Symbols.directions_car_rounded, "Car", ["car", "vehicle", "auto"]),
  _I("local_gas_station", Symbols.local_gas_station_rounded, "Fuel", ["fuel", "petrol", "gas", "adnoc", "enoc"]),
  _I("ev_station", Symbols.ev_station_rounded, "EV Charging", ["ev", "charging", "electric car"]),
  _I("local_parking", Symbols.local_parking_rounded, "Parking", ["parking", "rta"]),
  _I("local_taxi", Symbols.local_taxi_rounded, "Taxi", ["taxi", "cab", "uber", "careem"]),
  _I("hail", Symbols.hail_rounded, "Ride Hailing", ["ride", "uber", "careem", "hail"]),
  _I("car_repair", Symbols.car_repair_rounded, "Car Service", ["car", "service", "repair", "garage"]),
  _I("local_car_wash", Symbols.local_car_wash_rounded, "Car Wash", ["car wash", "cleaning"]),
  _I("tire_repair", Symbols.tire_repair_rounded, "Tyres", ["tyre", "tire", "repair"]),
  _I("car_rental", Symbols.car_rental_rounded, "Car Rental", ["rental", "car", "lease"]),
  _I("car_crash", Symbols.car_crash_rounded, "Car Insurance", ["insurance", "accident", "car"]),
  _I("traffic", Symbols.traffic_rounded, "Traffic Fines", ["traffic", "fine", "salik"]),
  _I("two_wheeler", Symbols.two_wheeler_rounded, "Motorbike", ["motorbike", "scooter", "bike"]),
  _I("pedal_bike", Symbols.pedal_bike_rounded, "Bicycle", ["bicycle", "bike", "cycling"]),
  _I("electric_scooter", Symbols.electric_scooter_rounded, "Scooter", ["scooter", "e-scooter"]),
  _I("directions_bus", Symbols.directions_bus_rounded, "Bus", ["bus", "transport", "nol"]),
  _I("train", Symbols.train_rounded, "Train", ["train", "railway"]),
  _I("subway", Symbols.subway_rounded, "Metro", ["metro", "subway", "nol"]),
  _I("tram", Symbols.tram_rounded, "Tram", ["tram", "transport"]),
  _I("directions_boat", Symbols.directions_boat_rounded, "Boat", ["boat", "ferry", "abra"]),
  _I("commute", Symbols.commute_rounded, "Commute", ["commute", "transport"]),
  _I("flight", Symbols.flight_rounded, "Flights", ["flight", "plane", "airline", "travel"]),
  _I("flight_takeoff", Symbols.flight_takeoff_rounded, "Flights", ["flight", "takeoff", "travel"]),
  _I("luggage", Symbols.luggage_rounded, "Travel", ["luggage", "travel", "trip"]),
  _I("hotel", Symbols.hotel_rounded, "Hotels", ["hotel", "stay", "accommodation"]),
  _I("king_bed", Symbols.king_bed_rounded, "Accommodation", ["hotel", "airbnb", "stay"]),
  _I("beach_access", Symbols.beach_access_rounded, "Holidays", ["holiday", "vacation", "beach"]),
  _I("travel_explore", Symbols.travel_explore_rounded, "Travel", ["travel", "explore"]),
  _I("map", Symbols.map_rounded, "Trips", ["map", "trip", "tour"]),
  _I("tour", Symbols.tour_rounded, "Tours", ["tour", "sightseeing"]),
  _I("id_card", Symbols.id_card_rounded, "Visa & ID", ["visa", "passport", "id", "emirates id"]),
  _I("mosque", Symbols.mosque_rounded, "Mosque", ["mosque", "masjid", "religion"]),

  // Health and fitness
  _I("medical_services", Symbols.medical_services_rounded, "Medical", ["medical", "doctor", "health"]),
  _I("local_hospital", Symbols.local_hospital_rounded, "Hospital", ["hospital", "health"]),
  _I("stethoscope", Symbols.stethoscope_rounded, "Doctor", ["doctor", "clinic", "checkup"]),
  _I("medication", Symbols.medication_rounded, "Pharmacy", ["pharmacy", "medicine", "drugs"]),
  _I("local_pharmacy", Symbols.local_pharmacy_rounded, "Pharmacy", ["pharmacy", "chemist"]),
  _I("vaccines", Symbols.vaccines_rounded, "Vaccines", ["vaccine", "injection"]),
  _I("dentistry", Symbols.dentistry_rounded, "Dentist", ["dentist", "teeth"]),
  _I("visibility", Symbols.visibility_rounded, "Eye Care", ["eye", "optician"]),
  _I("psychology", Symbols.psychology_rounded, "Therapy", ["therapy", "mental health"]),
  _I("favorite", Symbols.favorite_rounded, "Health", ["health", "heart", "love"]),
  _I("monitor_heart", Symbols.monitor_heart_rounded, "Health", ["heart", "health"]),
  _I("fitness_center", Symbols.fitness_center_rounded, "Gym", ["gym", "fitness", "workout"]),
  _I("exercise", Symbols.exercise_rounded, "Fitness", ["exercise", "fitness"]),
  _I("sports_gymnastics", Symbols.sports_gymnastics_rounded, "Yoga", ["yoga", "gymnastics"]),
  _I("self_improvement", Symbols.self_improvement_rounded, "Wellness", ["meditation", "wellness"]),
  _I("directions_run", Symbols.directions_run_rounded, "Running", ["running", "sport"]),
  _I("pool", Symbols.pool_rounded, "Swimming", ["pool", "swimming"]),
  _I("sports_soccer", Symbols.sports_soccer_rounded, "Football", ["football", "soccer", "sport"]),
  _I("sports_tennis", Symbols.sports_tennis_rounded, "Tennis", ["tennis", "padel", "sport"]),
  _I("sports_cricket", Symbols.sports_cricket_rounded, "Cricket", ["cricket", "sport"]),
  _I("sports_basketball", Symbols.sports_basketball_rounded, "Basketball", ["basketball", "sport"]),
  _I("golf_course", Symbols.golf_course_rounded, "Golf", ["golf", "sport"]),
  _I("hiking", Symbols.hiking_rounded, "Hiking", ["hiking", "outdoors"]),
  _I("sports_martial_arts", Symbols.sports_martial_arts_rounded, "Martial Arts", ["martial arts", "karate"]),

  // Entertainment and leisure
  _I("movie", Symbols.movie_rounded, "Movies", ["movie", "cinema", "film"]),
  _I("theaters", Symbols.theaters_rounded, "Cinema", ["cinema", "theater"]),
  _I("confirmation_number", Symbols.confirmation_number_rounded, "Tickets", ["tickets", "events"]),
  _I("local_activity", Symbols.local_activity_rounded, "Activities", ["activity", "tickets"]),
  _I("attractions", Symbols.attractions_rounded, "Theme Parks", ["theme park", "rides"]),
  _I("celebration", Symbols.celebration_rounded, "Celebrations", ["party", "celebration", "eid"]),
  _I("festival", Symbols.festival_rounded, "Events", ["festival", "event"]),
  _I("music_note", Symbols.music_note_rounded, "Music", ["music", "spotify", "anghami"]),
  _I("headphones", Symbols.headphones_rounded, "Audio", ["headphones", "audio"]),
  _I("podcasts", Symbols.podcasts_rounded, "Podcasts", ["podcast"]),
  _I("sports_esports", Symbols.sports_esports_rounded, "Gaming", ["gaming", "games", "playstation", "xbox"]),
  _I("stadia_controller", Symbols.stadia_controller_rounded, "Games", ["games", "controller"]),
  _I("casino", Symbols.casino_rounded, "Games", ["dice", "board games"]),
  _I("extension", Symbols.extension_rounded, "Hobbies", ["hobby", "puzzle"]),
  _I("palette", Symbols.palette_rounded, "Art", ["art", "painting", "hobby"]),
  _I("photo_camera", Symbols.photo_camera_rounded, "Photography", ["camera", "photography"]),
  _I("piano", Symbols.piano_rounded, "Instruments", ["piano", "music"]),
  _I("menu_book", Symbols.menu_book_rounded, "Books", ["books", "reading"]),
  _I("auto_stories", Symbols.auto_stories_rounded, "Books", ["books", "stories"]),
  _I("newspaper", Symbols.newspaper_rounded, "News", ["news", "newspaper", "magazine"]),
  _I("park", Symbols.park_rounded, "Outdoors", ["park", "outdoors"]),
  _I("camping", Symbols.camping_rounded, "Camping", ["camping", "tent", "desert"]),
  _I("kayaking", Symbols.kayaking_rounded, "Water Sports", ["kayak", "water sports"]),
  _I("scuba_diving", Symbols.scuba_diving_rounded, "Diving", ["diving", "scuba"]),
  _I("sailing", Symbols.sailing_rounded, "Sailing", ["sailing", "yacht"]),
  _I("nightlife", Symbols.nightlife_rounded, "Nightlife", ["nightlife", "club"]),

  // Education and work
  _I("school", Symbols.school_rounded, "Education", ["school", "education", "tuition", "fees"]),
  _I("backpack", Symbols.backpack_rounded, "School Supplies", ["school", "backpack"]),
  _I("library_books", Symbols.library_books_rounded, "Courses", ["courses", "books", "study"]),
  _I("history_edu", Symbols.history_edu_rounded, "University", ["university", "degree"]),
  _I("science", Symbols.science_rounded, "Science", ["science", "lab"]),
  _I("translate", Symbols.translate_rounded, "Languages", ["language", "course"]),
  _I("edit", Symbols.edit_rounded, "Stationery", ["stationery", "pen"]),
  _I("print", Symbols.print_rounded, "Printing", ["print", "office"]),
  _I("computer", Symbols.computer_rounded, "Computer", ["computer", "laptop", "pc"]),
  _I("laptop_mac", Symbols.laptop_mac_rounded, "Laptop", ["laptop", "macbook"]),
  _I("devices", Symbols.devices_rounded, "Electronics", ["devices", "electronics", "gadgets"]),
  _I("tablet_mac", Symbols.tablet_mac_rounded, "Tablet", ["tablet", "ipad"]),
  _I("watch_screentime", Symbols.watch_screentime_rounded, "Smartwatch", ["smartwatch", "watch"]),
  _I("keyboard", Symbols.keyboard_rounded, "Accessories", ["keyboard", "accessories"]),
  _I("mouse", Symbols.mouse_rounded, "Accessories", ["mouse", "accessories"]),
  _I("headset_mic", Symbols.headset_mic_rounded, "Headset", ["headset", "audio"]),
  _I("speaker", Symbols.speaker_rounded, "Speakers", ["speaker", "audio"]),
  _I("videogame_asset", Symbols.videogame_asset_rounded, "Consoles", ["console", "gaming"]),
  _I("memory", Symbols.memory_rounded, "Hardware", ["hardware", "chip"]),
  _I("battery_charging_full", Symbols.battery_charging_full_rounded, "Chargers", ["charger", "battery"]),
  _I("cable", Symbols.cable_rounded, "Cables", ["cable", "accessories"]),
  _I("code", Symbols.code_rounded, "Software", ["software", "apps", "code"]),
  _I("apps", Symbols.apps_rounded, "Apps", ["apps", "app store", "play store"]),
  _I("domain", Symbols.domain_rounded, "Domains & Hosting", ["domain", "hosting", "website"]),
  _I("smart_toy", Symbols.smart_toy_rounded, "AI Tools", ["ai", "bot", "chatgpt", "claude"]),

  // Misc
  _I("folder", Symbols.folder_rounded, "Group", ["folder", "group"]),
  _I("folder_copy", Symbols.folder_copy_rounded, "Groups", ["folder", "groups"]),
  _I("category", Symbols.category_rounded, "General", ["general", "other", "misc"]),
  _I("more_horiz", Symbols.more_horiz_rounded, "Other", ["other", "misc"]),
  _I("help", Symbols.help_rounded, "Unknown", ["unknown", "question"]),
  _I("star", Symbols.star_rounded, "Favourites", ["star", "favourite"]),
  _I("bookmark", Symbols.bookmark_rounded, "Saved", ["bookmark", "saved"]),
  _I("label", Symbols.label_rounded, "Tag", ["label", "tag"]),
  _I("flag", Symbols.flag_rounded, "Goals", ["goal", "flag", "target"]),
  _I("emoji_events", Symbols.emoji_events_rounded, "Achievements", ["trophy", "goal", "award"]),
  _I("rocket_launch", Symbols.rocket_launch_rounded, "Projects", ["rocket", "project", "startup"]),
  _I("lightbulb", Symbols.lightbulb_rounded, "Ideas", ["idea", "lightbulb"]),
  _I("event", Symbols.event_rounded, "Events", ["event", "calendar"]),
  _I("calendar_month", Symbols.calendar_month_rounded, "Monthly", ["monthly", "calendar"]),
  _I("schedule", Symbols.schedule_rounded, "Time", ["time", "clock"]),
  _I("alarm", Symbols.alarm_rounded, "Reminders", ["alarm", "reminder"]),
  _I("public", Symbols.public_rounded, "Abroad", ["abroad", "world", "international"]),
  _I("send_money", Symbols.send_money_rounded, "Remittance", ["remittance", "send money", "transfer", "home"]),
  _I("swap_horiz", Symbols.swap_horiz_rounded, "Transfers", ["transfer", "swap"]),
  _I("sync_alt", Symbols.sync_alt_rounded, "Transfers", ["transfer", "sync"]),
  _I("arrow_downward", Symbols.arrow_downward_rounded, "Income", ["income", "in"]),
  _I("arrow_upward", Symbols.arrow_upward_rounded, "Expense", ["expense", "out"]),
  _I("warning", Symbols.warning_rounded, "Emergency", ["emergency", "warning"]),
  _I("emergency", Symbols.emergency_rounded, "Emergency Fund", ["emergency", "fund"]),
  _I("church", Symbols.church_rounded, "Church", ["church", "religion"]),
  _I("temple_hindu", Symbols.temple_hindu_rounded, "Temple", ["temple", "religion"]),
  _I("synagogue", Symbols.synagogue_rounded, "Synagogue", ["synagogue", "religion"]),
  _I("smoking_rooms", Symbols.smoking_rooms_rounded, "Smoking", ["smoking", "cigarettes", "shisha"]),
  _I("local_post_office", Symbols.local_post_office_rounded, "Post Office", ["post", "courier"]),
  _I("inventory_2", Symbols.inventory_2_rounded, "Storage", ["storage", "boxes", "moving"]),
  _I("moving", Symbols.moving_rounded, "Moving", ["moving", "relocation"]),
  _I("description", Symbols.description_rounded, "Documents", ["documents", "paperwork", "fees"]),
  _I("assignment", Symbols.assignment_rounded, "Government Fees", ["government", "fees", "typing", "amer"]),
  _I("account_box", Symbols.account_box_rounded, "Account", ["account", "profile"]),
];
