# AMEEN: post-processes the generated translation files.
# Runs automatically at the end of generate-translations.py, and can be run on
# its own: python ameen-apply-overrides.py
#  1. Replaces the upstream app name in every value with Ameen's.
#  2. Merges ameen-overrides.json: {"*": {...all languages}, "en": {...}, ...}
#     Keys under a language override keys under "*".
import json
import os

dir_path = os.path.dirname(os.path.realpath(__file__))
generated_path = os.path.join(dir_path, "generated")
overrides_path = os.path.join(dir_path, "ameen-overrides.json")

UPSTREAM_NAME = "Cashew"
APP_NAME = "Ameen"

with open(overrides_path, "r", encoding="utf-8") as file:
    overrides = json.load(file)

for file_name in sorted(os.listdir(generated_path)):
    if not file_name.endswith(".json"):
        continue
    lang = file_name[:-len(".json")]
    path = os.path.join(generated_path, file_name)
    with open(path, "r", encoding="utf-8") as file:
        data = json.load(file)
    for key, value in data.items():
        if isinstance(value, str):
            data[key] = value.replace(UPSTREAM_NAME, APP_NAME)
    # Only the base language gets every new key, other languages fall back to it
    if lang == "en" or lang == "none":
        data.update(overrides.get("*", {}))
    else:
        data.update({k: v for k, v in overrides.get("*", {}).items() if k in data})
    data.update(overrides.get(lang, {}))
    with open(path, "w", encoding="utf-8", newline="\n") as file:
        json.dump(data, file, indent=2, ensure_ascii=False)
    print("Applied Ameen overrides -", lang)
