"""
Small script to merge bookmarks from browsers
"""

import json
import plistlib

links: dict[str, str] = {}

with open("arc.json", encoding="utf-8") as f:
    data = json.load(f)

    for item in data["sidebar"]["containers"][1]["items"]:
        if not isinstance(item, str):
            if "data" in item and "tab" in item["data"]:
                title = (
                    item["data"]["tab"]["savedTitle"]
                    if "savedTitle" in item["data"]["tab"]
                    else item["title"]
                )
                url = item["data"]["tab"]["savedURL"]
                links[url] = title

with open("orion.plist", "br") as f:
    data = plistlib.load(f)

    for key in data:
        title = data[key]["title"]
        if "url" in data[key]:
            url = data[key]["url"]
            if url not in links:
                links[url] = title

links = dict(sorted(links.items()))

with open("links.json", mode="w", encoding="utf-8") as f:
    json.dump(links, f, indent=4, ensure_ascii=False)
