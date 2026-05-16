#!/usr/bin/env python3
"""
Enrich Hörspiel catalog JSONs with Spotify and Apple Music URLs.

Apple Music: Uses the free iTunes Search API (no auth needed).
Spotify: Uses the Spotify Web API (needs client credentials).

Usage:
  # Apple Music only (no setup needed):
  python3 enrich_catalogs.py --apple-only

  # Both services:
  export SPOTIFY_CLIENT_ID=your_id
  export SPOTIFY_CLIENT_SECRET=your_secret
  python3 enrich_catalogs.py

  # Dry run (print matches without writing):
  python3 enrich_catalogs.py --dry-run

  # Single catalog:
  python3 enrich_catalogs.py --catalog "Die drei ???"
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
import urllib.parse
import urllib.error
from pathlib import Path

CATALOGS = {
    "Die drei ???": {
        "spotify_artist_id": "3meJIgRw7YleJrmbpbJK6S",
        "apple_music_artist_id": "201306317",
        "catalog_url": "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/the_three_investigators.json",
        "local_filename": "de/the_three_investigators.json",
        "number_prefix": "Folge",
        "series_prefix": "Die drei ???",
    },
    "Die drei ??? Kids": {
        "spotify_artist_id": "0vLsqW05dyLvjuKKftAEGA",
        "apple_music_artist_id": "305761269",
        "catalog_url": "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/the_three_investigators_kids.json",
        "local_filename": "de/the_three_investigators_kids.json",
        "number_prefix": "Folge",
        "series_prefix": "Die drei ??? Kids",
    },
    "Die drei !!!": {
        "spotify_artist_id": "2Jc4AEeBTE47KwuKgYOtcL",
        "apple_music_artist_id": "329049924",
        "catalog_url": "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/the_three_exclamation_marks.json",
        "local_filename": "de/the_three_exclamation_marks.json",
        "number_prefix": "Folge",
        "series_prefix": "Die drei !!!",
    },
    "Bibi Blocksberg": {
        "spotify_artist_id": "3t2iKODSDyzoDJw7AsD99u",
        "apple_music_artist_id": "41480004",
        "catalog_url": "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/bibi_blocksberg.json",
        "local_filename": "de/bibi_blocksberg.json",
        "number_prefix": "Folge",
        "series_prefix": "Bibi Blocksberg",
    },
    "TKKG": {
        "spotify_artist_id": "61qDotnjM0jnY5lkfOP7ve",
        "apple_music_artist_id": "191548811",
        "catalog_url": None,
        "local_filename": "de/tkkg.json",
        "number_prefix": "Folge",
        "series_prefix": "TKKG",
    },
}

# --- Number extraction ---

EPISODE_NUMBER_PATTERNS = [
    re.compile(r"(?:Folge|Episode|Nr\.?)\s*(\d+)", re.IGNORECASE),
    re.compile(r"^(\d{1,3})\s*[/:\-–]"),
    re.compile(r"^0*(\d+)\s*[/:\-–]"),
]


def extract_episode_number(album_name: str) -> "int | None":
    for pattern in EPISODE_NUMBER_PATTERNS:
        m = pattern.search(album_name)
        if m:
            return int(m.group(1))
    return None


# --- Apple Music (iTunes Search API, no auth) ---


def fetch_apple_music_albums(artist_id: str) -> list[dict]:
    url = (
        f"https://itunes.apple.com/lookup?id={artist_id}"
        f"&entity=album&limit=200&country=de"
    )
    try:
        with urllib.request.urlopen(url, timeout=30) as resp:
            data = json.loads(resp.read())
    except urllib.error.URLError as e:
        print(f"  Apple Music API error: {e}", file=sys.stderr)
        return []

    albums = []
    for r in data.get("results", []):
        if r.get("wrapperType") != "collection":
            continue
        name = r.get("collectionName", "")
        view_url = r.get("collectionViewUrl", "")
        if view_url:
            view_url = view_url.split("?")[0]
        albums.append({"name": name, "url": view_url})

    return albums


# --- Spotify Web API ---


def get_spotify_token(client_id: str, client_secret: str) -> "str | None":
    import base64

    auth = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    req = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=b"grant_type=client_credentials",
        headers={
            "Authorization": f"Basic {auth}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read())
            return data.get("access_token")
    except urllib.error.URLError as e:
        print(f"  Spotify auth error: {e}", file=sys.stderr)
        return None


def fetch_spotify_albums(artist_id: str, token: str) -> list[dict]:
    albums = []
    offset = 0
    limit = 50

    while True:
        url = (
            f"https://api.spotify.com/v1/artists/{artist_id}/albums"
            f"?include_groups=album,single&limit={limit}&offset={offset}&market=DE"
        )
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})

        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
        except urllib.error.URLError as e:
            print(f"  Spotify API error: {e}", file=sys.stderr)
            break

        items = data.get("items", [])
        if not items:
            break

        for item in items:
            name = item.get("name", "")
            ext_url = item.get("external_urls", {}).get("spotify", "")
            albums.append({"name": name, "url": ext_url})

        if not data.get("next"):
            break
        offset += limit
        time.sleep(0.3)

    return albums


# --- Matching ---


def match_albums_to_catalog(
    catalog_entries: list[dict], albums: list[dict], service_name: str
) -> dict[int, str]:
    album_by_number: dict[int, str] = {}

    for album in albums:
        num = extract_episode_number(album["name"])
        if num is not None and album["url"]:
            if num not in album_by_number:
                album_by_number[num] = album["url"]

    matched = {}
    for entry in catalog_entries:
        num = entry["number"]
        if num in album_by_number:
            matched[num] = album_by_number[num]

    return matched


# --- Main ---


def load_catalog(catalog_info: dict) -> "dict | None":
    url = catalog_info.get("catalog_url")
    if not url:
        return None
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            return json.loads(resp.read())
    except urllib.error.URLError as e:
        print(f"  Could not load catalog: {e}", file=sys.stderr)
        return None


def enrich_catalog(
    catalog_name: str,
    catalog_info: dict,
    spotify_token,
    dry_run: bool,
    output_dir: Path,
):
    print(f"\n{'='*60}")
    print(f"  {catalog_name}")
    print(f"{'='*60}")

    catalog_data = load_catalog(catalog_info)
    if not catalog_data:
        print(f"  Skipping (no catalog URL)")
        return

    entries = catalog_data.get("entries", [])
    print(f"  Catalog has {len(entries)} entries")

    # Apple Music
    print(f"  Fetching Apple Music albums...")
    apple_albums = fetch_apple_music_albums(catalog_info["apple_music_artist_id"])
    print(f"  Found {len(apple_albums)} Apple Music albums")
    apple_matches = match_albums_to_catalog(entries, apple_albums, "Apple Music")
    print(f"  Matched {len(apple_matches)}/{len(entries)} entries")

    # Spotify
    spotify_matches: dict[int, str] = {}
    if spotify_token:
        print(f"  Fetching Spotify albums...")
        spotify_albums = fetch_spotify_albums(catalog_info["spotify_artist_id"], spotify_token)
        print(f"  Found {len(spotify_albums)} Spotify albums")
        spotify_matches = match_albums_to_catalog(entries, spotify_albums, "Spotify")
        print(f"  Matched {len(spotify_matches)}/{len(entries)} entries")
    else:
        print(f"  Skipping Spotify (no credentials)")

    # Enrich entries
    enriched_entries = []
    for entry in entries:
        num = entry["number"]
        enriched = dict(entry)
        if num in spotify_matches:
            enriched["spotifyURL"] = spotify_matches[num]
        if num in apple_matches:
            enriched["appleMusicURL"] = apple_matches[num]
        enriched_entries.append(enriched)

    total_with_links = sum(
        1 for e in enriched_entries if e.get("spotifyURL") or e.get("appleMusicURL")
    )
    print(f"  Result: {total_with_links}/{len(entries)} entries have at least one link")

    if dry_run:
        print(f"\n  Sample (first 3 with links):")
        shown = 0
        for e in enriched_entries:
            if e.get("spotifyURL") or e.get("appleMusicURL"):
                print(f"    #{e['number']} {e['title']}")
                if e.get("spotifyURL"):
                    print(f"      Spotify: {e['spotifyURL']}")
                if e.get("appleMusicURL"):
                    print(f"      Apple:   {e['appleMusicURL']}")
                shown += 1
                if shown >= 3:
                    break
        return

    # Write enriched catalog
    output_data = {
        "collectionName": catalog_data.get("collectionName", catalog_name),
        "entries": enriched_entries,
    }

    output_path = output_dir / catalog_info["local_filename"]
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"  Written to {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Enrich Hörspiel catalogs with streaming URLs")
    parser.add_argument("--dry-run", action="store_true", help="Print matches without writing")
    parser.add_argument("--apple-only", action="store_true", help="Skip Spotify (no credentials needed)")
    parser.add_argument("--catalog", type=str, help="Process only this catalog")
    parser.add_argument(
        "--output-dir",
        type=str,
        default="catalogs",
        help="Output directory for enriched JSONs (default: catalogs/)",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir)

    # Spotify auth
    spotify_token = None
    if not args.apple_only:
        client_id = os.environ.get("SPOTIFY_CLIENT_ID", "")
        client_secret = os.environ.get("SPOTIFY_CLIENT_SECRET", "")
        if client_id and client_secret:
            print("Authenticating with Spotify...")
            spotify_token = get_spotify_token(client_id, client_secret)
            if spotify_token:
                print("Spotify auth successful")
            else:
                print("Spotify auth failed, continuing with Apple Music only")
        else:
            print("No SPOTIFY_CLIENT_ID/SECRET set, skipping Spotify")
            print("Set these env vars or use --apple-only")

    catalogs_to_process = CATALOGS
    if args.catalog:
        if args.catalog not in CATALOGS:
            print(f"Unknown catalog: {args.catalog}")
            print(f"Available: {', '.join(CATALOGS.keys())}")
            sys.exit(1)
        catalogs_to_process = {args.catalog: CATALOGS[args.catalog]}

    for name, info in catalogs_to_process.items():
        enrich_catalog(name, info, spotify_token, args.dry_run, output_dir)

    print(f"\nDone!")
    if not args.dry_run:
        print(f"Enriched catalogs written to {output_dir}/")
        print(f"Copy them to your hoerspiel-kataloge repo and push.")


if __name__ == "__main__":
    main()
