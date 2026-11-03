#!/usr/bin/env python3
"""
Luna Stream 4K IPTV - 24/7 Cloud Auto-Poster for X / Twitter API v2
Zero external dependencies (uses Python standard library only).
Reads templates from data/tweet_templates.json and posts via OAuth 1.0a HMAC-SHA1.
"""

import base64
import datetime
import hashlib
import hmac
import json
import os
import random
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(ROOT_DIR, "data")
CONFIG_PATH = os.path.join(DATA_DIR, "bot_config.json")
TEMPLATES_PATH = os.path.join(DATA_DIR, "tweet_templates.json")


def load_json(path, default):
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return default


def percent_encode(val: str) -> str:
    return urllib.parse.quote(str(val), safe="-._~")


def build_promotional_tweet() -> str:
    cfg = load_json(CONFIG_PATH, {})
    tpl_data = load_json(TEMPLATES_PATH, {})

    wa_num = cfg.get("whatsapp_number", "+44 7882 507089")
    wa_digits = "".join(ch for ch in wa_num if ch.isdigit()) or "447882507089"
    short_wa = f"https://wa.me/{wa_digits}"
    netlify_url = cfg.get("netlify_url", "https://luna-4k-pass.netlify.app")
    website_url = cfg.get("website_url", "https://lunaentertainment.online")

    # Rotate CTA based on current 3-hour slot of the day (0..7) so every slot uses a different link
    hour_slot = (datetime.datetime.now(datetime.timezone.utc).hour // 3) % 4
    if hour_slot == 0:
        cta = f"👉 24H Trial & Info: {netlify_url}"
    elif hour_slot == 1:
        cta = f"💬 WhatsApp 24H Free Trial: {short_wa}"
    elif hour_slot == 2:
        cta = f"🌐 Official Plans & Trial: {website_url}"
    else:
        cta = f"📲 WhatsApp {wa_num} | {netlify_url}"

    templates = tpl_data.get("templates", [])
    hooks = tpl_data.get("hooks", ["🔥 Stop dealing with buffering streams!"])
    hashtags_map = tpl_data.get("hashtags_by_category", {})

    tpl = random.choice(templates)
    cat = tpl.get("category", "football")
    hook = random.choice(hooks)
    tag_pool = hashtags_map.get(cat, ["#IPTV", "#FireStick", "#SmartTV", "#4KStreaming"])
    chosen_tags = " ".join(random.sample(tag_pool, k=min(3, len(tag_pool))))

    body = tpl.get("body", "{hook}\n\n{cta}\n{hashtags}")
    tweet = body.replace("{hook}", hook).replace("{cta}", cta).replace("{hashtags}", chosen_tags).strip()

    if len(tweet) > 275:
        short_tags = " ".join(tag_pool[:2])
        tweet = body.replace("{hook}", hook).replace("{cta}", cta).replace("{hashtags}", short_tags).strip()

    return tweet


def post_tweet_oauth1(tweet_text: str, api_key: str, api_secret: str, access_token: str, access_secret: str):
    url = "https://api.twitter.com/2/tweets"
    method = "POST"
    oauth_params = {
        "oauth_consumer_key": api_key,
        "oauth_nonce": uuid.uuid4().hex,
        "oauth_signature_method": "HMAC-SHA1",
        "oauth_timestamp": str(int(time.time())),
        "oauth_token": access_token,
        "oauth_version": "1.0",
    }

    sorted_params = "&".join(
        f"{percent_encode(k)}={percent_encode(v)}" for k, v in sorted(oauth_params.items())
    )
    base_string = f"{method}&{percent_encode(url)}&{percent_encode(sorted_params)}"
    signing_key = f"{percent_encode(api_secret)}&{percent_encode(access_secret)}"

    hashed = hmac.new(signing_key.encode("ascii"), base_string.encode("ascii"), hashlib.sha1)
    signature = base64.b64encode(hashed.digest()).decode("ascii")
    oauth_params["oauth_signature"] = signature

    auth_header = "OAuth " + ", ".join(
        f'{percent_encode(k)}="{percent_encode(v)}"' for k, v in sorted(oauth_params.items())
    )

    payload = json.dumps({"text": tweet_text}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Authorization": auth_header,
            "Content-Type": "application/json; charset=utf-8",
            "User-Agent": "LunaStreamAutoPromoter/1.0",
        },
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=20) as resp:
        resp_body = resp.read().decode("utf-8")
        return json.loads(resp_body)


def main():
    cfg = load_json(CONFIG_PATH, {})
    api_key = (os.environ.get("X_API_KEY") or cfg.get("x_api_key") or "").strip()
    api_secret = (os.environ.get("X_API_SECRET") or cfg.get("x_api_secret") or "").strip()
    access_token = (os.environ.get("X_ACCESS_TOKEN") or cfg.get("x_access_token") or "").strip()
    access_secret = (os.environ.get("X_ACCESS_SECRET") or cfg.get("x_access_secret") or "").strip()

    tweet_text = build_promotional_tweet()
    print("=== Generated Promotional Tweet ===")
    print(tweet_text)
    print("===================================")

    if not all([api_key, api_secret, access_token, access_secret]):
        raise SystemExit(
            "Missing X API credentials. Set X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, and X_ACCESS_SECRET in GitHub Actions Secrets or data/bot_config.json."
        )

    try:
        result = post_tweet_oauth1(tweet_text, api_key, api_secret, access_token, access_secret)
        print("Successfully posted tweet:", json.dumps(result))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        raise SystemExit(f"X API HTTPError {e.code}: {err_body}")


if __name__ == "__main__":
    main()
