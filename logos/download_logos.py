#!/usr/bin/env python3
"""
HomeTeam logo pipeline.
Fetches light/white team and streaming logos and saves them locally.
Run once before initial release, then only when teams/branding changes.
"""

import urllib.request
import urllib.error
import json
import os
import sys
import time
from datetime import datetime, timezone

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
TEAMS_DIR = os.path.join(OUT_DIR, "teams")
STREAMING_DIR = os.path.join(OUT_DIR, "streaming")

os.makedirs(TEAMS_DIR, exist_ok=True)
os.makedirs(STREAMING_DIR, exist_ok=True)

manifest = {"generated": datetime.now(timezone.utc).isoformat(), "teams": {}, "streaming": {}}
results = {"ok": 0, "missing": 0, "skipped": 0}

HEADERS = {"User-Agent": "HomeTeam-LogoPipeline/1.0"}

def fetch(url):
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            if r.status != 200:
                return None, f"HTTP {r.status}"
            data = r.read()
            if len(data) < 512:
                return None, f"Too small ({len(data)} bytes)"
            ct = r.headers.get("Content-Type", "")
            if not ct.startswith("image/"):
                return None, f"Not an image (Content-Type: {ct})"
            return data, None
    except urllib.error.HTTPError as e:
        return None, f"HTTP {e.code}"
    except Exception as e:
        return None, str(e)

def save_team(composite_id, data, source):
    filename = composite_id.replace(":", "_") + ".png"
    path = os.path.join(TEAMS_DIR, filename)
    with open(path, "wb") as f:
        f.write(data)
    manifest["teams"][composite_id] = {
        "status": "ok", "file": f"teams/{filename}",
        "source": source, "size_bytes": len(data)
    }
    results["ok"] += 1
    return filename

def fail_team(composite_id, reason):
    manifest["teams"][composite_id] = {"status": "missing", "reason": reason}
    results["missing"] += 1
    print(f"  MISSING {composite_id}: {reason}")

def fetch_team_logo(composite_id, sport, abbrev):
    abbrev_lower = abbrev.lower()
    sport_map = {"nhl": "nhl", "mlb": "mlb", "nfl": "nfl", "nba": "nba"}
    espn_sport = sport_map.get(sport)

    if espn_sport:
        # Try dark variant first (white logo for dark backgrounds)
        dark_url = f"https://a.espncdn.com/i/teamlogos/{espn_sport}/500-dark/{abbrev_lower}.png"
        data, err = fetch(dark_url)
        if data:
            filename = save_team(composite_id, data, "espn-dark")
            print(f"  OK  {composite_id} ({abbrev}) — espn-dark")
            return

        # Fall back to regular variant
        reg_url = f"https://a.espncdn.com/i/teamlogos/{espn_sport}/500/{abbrev_lower}.png"
        data, err2 = fetch(reg_url)
        if data:
            filename = save_team(composite_id, data, "espn-regular")
            print(f"  OK  {composite_id} ({abbrev}) — espn-regular (dark 404'd)")
            return

        fail_team(composite_id, f"dark: {err} | regular: {err2}")
    else:
        fail_team(composite_id, f"No ESPN logo path for sport '{sport}'")

def fetch_soccer_teams(league_path, sport_key):
    print(f"\nFetching {sport_key} teams from ESPN API...")
    api_url = f"https://site.api.espn.com/apis/site/v2/sports/soccer/{league_path}/teams?limit=100"
    try:
        req = urllib.request.Request(api_url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=15) as r:
            payload = json.loads(r.read())
        teams = payload.get("sports", [{}])[0].get("leagues", [{}])[0].get("teams", [])
        print(f"  Found {len(teams)} teams")
        for entry in teams:
            team = entry.get("team", {})
            tid = str(team.get("id", ""))
            abbrev = team.get("abbreviation", tid)
            composite_id = f"{sport_key}:{tid}"
            logos = team.get("logos", [])
            logo_url = None
            # Prefer dark/white variant
            for logo in logos:
                href = logo.get("href", "")
                if "dark" in href or "white" in href:
                    logo_url = href
                    break
            if not logo_url and logos:
                logo_url = logos[0].get("href")
            if logo_url:
                data, err = fetch(logo_url)
                if data:
                    save_team(composite_id, data, "espn-api")
                    print(f"  OK  {composite_id} ({abbrev})")
                else:
                    fail_team(composite_id, err)
            else:
                fail_team(composite_id, "No logo URL in ESPN API response")
            time.sleep(0.05)
    except Exception as e:
        print(f"  ERROR fetching {sport_key}: {e}")

def fetch_racing_athletes(league_path, sport_key):
    print(f"\nFetching {sport_key} athletes from ESPN API...")
    api_url = f"https://site.api.espn.com/apis/site/v2/sports/racing/{league_path}/athletes?limit=100"
    try:
        req = urllib.request.Request(api_url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=15) as r:
            payload = json.loads(r.read())
        athletes = payload.get("athletes", [])
        print(f"  Found {len(athletes)} athletes")
        for ath in athletes:
            aid = str(ath.get("id", ""))
            name = ath.get("displayName", aid)
            composite_id = f"{sport_key}:{aid}"
            # Try headshot
            headshot = ath.get("headshot", {})
            url = headshot.get("href") if headshot else None
            if url:
                data, err = fetch(url)
                if data:
                    save_team(composite_id, data, "espn-headshot")
                    print(f"  OK  {composite_id} ({name})")
                else:
                    fail_team(composite_id, err)
            else:
                fail_team(composite_id, f"No headshot for {name}")
            time.sleep(0.05)
    except Exception as e:
        print(f"  ERROR fetching {sport_key}: {e}")

# ── NHL ─────────────────────────────────────────────────────────────────────
nhl_teams = [
    ("nhl:25","ANA"),("nhl:1","BOS"),("nhl:2","BUF"),("nhl:3","CGY"),
    ("nhl:7","CAR"),("nhl:4","CHI"),("nhl:17","COL"),("nhl:29","CBJ"),
    ("nhl:9","DAL"),("nhl:5","DET"),("nhl:6","EDM"),("nhl:26","FLA"),
    ("nhl:8","LA"),("nhl:30","MIN"),("nhl:10","MTL"),("nhl:27","NSH"),
    ("nhl:11","NJ"),("nhl:12","NYI"),("nhl:13","NYR"),("nhl:14","OTT"),
    ("nhl:15","PHI"),("nhl:16","PIT"),("nhl:18","SJ"),("nhl:19","STL"),
    ("nhl:20","TB"),("nhl:21","TOR"),("nhl:22","VAN"),("nhl:37","VGK"),
    ("nhl:23","WSH"),("nhl:28","WPG"),("nhl:124292","SEA"),
]
print("\nNHL:")
for cid, abbrev in nhl_teams:
    fetch_team_logo(cid, "nhl", abbrev)
    time.sleep(0.05)

# ── MLB ──────────────────────────────────────────────────────────────────────
mlb_teams = [
    ("mlb:1","BAL"),("mlb:2","BOS"),("mlb:3","CHW"),("mlb:4","CLE"),
    ("mlb:5","DET"),("mlb:6","HOU"),("mlb:7","KC"),("mlb:8","LAA"),
    ("mlb:9","MIN"),("mlb:10","NYY"),("mlb:11","OAK"),("mlb:12","SEA"),
    ("mlb:13","TB"),("mlb:14","TEX"),("mlb:15","TOR"),("mlb:16","ARI"),
    ("mlb:17","ATL"),("mlb:18","CHC"),("mlb:19","CIN"),("mlb:20","COL"),
    ("mlb:21","LAD"),("mlb:22","MIA"),("mlb:23","MIL"),("mlb:24","NYM"),
    ("mlb:25","PHI"),("mlb:26","PIT"),("mlb:27","SD"),("mlb:28","SF"),
    ("mlb:29","STL"),("mlb:30","WSH"),
]
print("\nMLB:")
for cid, abbrev in mlb_teams:
    fetch_team_logo(cid, "mlb", abbrev)
    time.sleep(0.05)

# ── NFL ──────────────────────────────────────────────────────────────────────
nfl_teams = [
    ("nfl:1","ATL"),("nfl:2","BUF"),("nfl:3","CHI"),("nfl:4","CIN"),
    ("nfl:5","CLE"),("nfl:6","DAL"),("nfl:7","DEN"),("nfl:8","DET"),
    ("nfl:9","GB"),("nfl:10","TEN"),("nfl:11","IND"),("nfl:12","KC"),
    ("nfl:13","LV"),("nfl:14","LAR"),("nfl:15","MIA"),("nfl:16","MIN"),
    ("nfl:17","NE"),("nfl:18","NO"),("nfl:19","NYG"),("nfl:20","NYJ"),
    ("nfl:21","PHI"),("nfl:22","ARI"),("nfl:23","PIT"),("nfl:24","LAC"),
    ("nfl:25","SF"),("nfl:26","SEA"),("nfl:27","TB"),("nfl:28","WSH"),
    ("nfl:29","CAR"),("nfl:30","JAX"),("nfl:33","BAL"),("nfl:34","HOU"),
]
print("\nNFL:")
for cid, abbrev in nfl_teams:
    fetch_team_logo(cid, "nfl", abbrev)
    time.sleep(0.05)

# ── NBA ──────────────────────────────────────────────────────────────────────
nba_teams = [
    ("nba:1","ATL"),("nba:2","BOS"),("nba:3","NO"),("nba:4","CHI"),
    ("nba:5","CLE"),("nba:6","DAL"),("nba:7","DEN"),("nba:8","DET"),
    ("nba:9","GS"),("nba:10","HOU"),("nba:11","IND"),("nba:12","LAC"),
    ("nba:13","LAL"),("nba:14","MEM"),("nba:15","MIA"),("nba:16","MIL"),
    ("nba:17","MIN"),("nba:18","BKN"),("nba:19","NY"),("nba:20","ORL"),
    ("nba:21","PHI"),("nba:22","PHX"),("nba:23","POR"),("nba:24","SAC"),
    ("nba:25","SA"),("nba:26","OKC"),("nba:27","UTA"),("nba:28","WSH"),
    ("nba:29","TOR"),
]
print("\nNBA:")
for cid, abbrev in nba_teams:
    fetch_team_logo(cid, "nba", abbrev)
    time.sleep(0.05)

# ── MLS + Premier League (via ESPN API) ──────────────────────────────────────
fetch_soccer_teams("usa.1", "mls")
fetch_soccer_teams("eng.1", "premierLeague")

# ── F1 athletes (headshots, not used for logos — team SVGs committed manually)
# fetch_racing_athletes("f1", "f1")  # headshots are not team logos

# ── MotoGP team logos (official MotoGP API, transparent PNGs) ─────────────────
# Filename: motoGP_{espnTeamID}.png  (matches AppGroupStore.logoFileURL convention)
motogp_teams = [
    ("motoGP_motogp_ducati_lenovo",
        "https://photos.motogp.com/teams/8/9/892fff2f-7402-4fbd-99fb-5fd567d8a80c/main-picture.png"),
    ("motoGP_motogp_pramac",
        "https://photos.motogp.com/teams/5/9/598ccfb2-e0f1-4ad7-92b7-00ec9238a72c/main-picture.png"),
    ("motoGP_motogp_aprilia",
        "https://photos.motogp.com/teams/1/1/11d18b37-baba-400a-80c2-f8ddf040f97e/main-picture.png"),
    ("motoGP_motogp_ktm",
        "https://photos.motogp.com/teams/0/b/0b6cc118-a286-4343-9020-fb53c6f77c1a/main-picture.png"),
    ("motoGP_motogp_gresini",
        "https://photos.motogp.com/teams/1/1/11729e67-d2cb-41ad-b3a8-4a0ac5768a5f/main-picture.png"),
    ("motoGP_motogp_vr46",
        "https://photos.motogp.com/teams/4/1/4130a48f-fa91-48be-a50c-f8a2e3f863a0/main-picture.png"),
    ("motoGP_motogp_honda_repsol",
        "https://photos.motogp.com/teams/c/e/ce837bd3-bc07-40ef-83cf-6a8025bededf/main-picture.png"),
    ("motoGP_motogp_yamaha",
        "https://photos.motogp.com/teams/1/4/141b6f0f-7e53-4d27-9bdb-0ea8fba7e842/main-picture.png"),
]
print("\nMotoGP teams:")
for filename_id, url in motogp_teams:
    data, err = fetch(url)
    if data:
        path = os.path.join(TEAMS_DIR, f"{filename_id}.png")
        with open(path, "wb") as f:
            f.write(data)
        manifest["teams"][filename_id] = {
            "status": "ok", "file": f"teams/{filename_id}.png",
            "source": url, "size_bytes": len(data)
        }
        results["ok"] += 1
        print(f"  OK  {filename_id} ({len(data)} bytes)")
    else:
        manifest["teams"][filename_id] = {"status": "missing", "reason": err}
        results["missing"] += 1
        print(f"  MISSING {filename_id}: {err}")

# ── Streaming services ────────────────────────────────────────────────────────
# Sources: official press/brand kit URLs for white variants
streaming_sources = {
    "espn-plus": [
        "https://a.espncdn.com/redesign/assets/img/logos/espnplus/espnplus_200x200.png",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/2/26/ESPN_Plus_logo.svg/200px-ESPN_Plus_logo.svg.png",
    ],
    "hulu": [
        "https://press.hulu.com/app/uploads/Hulu_Logo_Green.png",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e4/Hulu_Logo.svg/200px-Hulu_Logo.svg.png",
    ],
    "hulu-tv": [
        "https://press.hulu.com/app/uploads/Hulu_Logo_Green.png",
    ],
    "paramount": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Paramount_Network_logo.svg/200px-Paramount_Network_logo.svg.png",
        "https://upload.wikimedia.org/wikipedia/en/thumb/a/a5/Paramount_plus_logo.svg/200px-Paramount_plus_logo.svg.png",
    ],
    "amazon": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Amazon_Prime_Video_logo.svg/200px-Amazon_Prime_Video_logo.svg.png",
    ],
    "peacock": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/NBCUniversal_Peacock_Logo.svg/200px-NBCUniversal_Peacock_Logo.svg.png",
    ],
    "hbo": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/d/de/Max-Logo.svg/200px-Max-Logo.svg.png",
    ],
    "youtube-tv": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/Logo_of_YouTube_%282015-2017%29.svg/200px-Logo_of_YouTube_%282015-2017%29.svg.png",
    ],
    "netflix": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Netflix_2015_logo.svg/200px-Netflix_2015_logo.svg.png",
    ],
}

print("\nStreaming services:")
for service_id, urls in streaming_sources.items():
    downloaded = False
    last_err = "no URLs tried"
    for url in urls:
        data, err = fetch(url)
        if data:
            filename = f"{service_id}.png"
            path = os.path.join(STREAMING_DIR, filename)
            with open(path, "wb") as f:
                f.write(data)
            manifest["streaming"][service_id] = {
                "status": "ok", "file": f"streaming/{filename}",
                "source": url, "size_bytes": len(data)
            }
            results["ok"] += 1
            print(f"  OK  {service_id} ({len(data)} bytes)")
            downloaded = True
            break
        last_err = err
        time.sleep(0.1)
    if not downloaded:
        manifest["streaming"][service_id] = {"status": "missing", "reason": last_err}
        results["missing"] += 1
        print(f"  MISSING {service_id}: {last_err}")

# Apple TV uses SF Symbol — no file needed
manifest["streaming"]["apple-tv"] = {
    "status": "uses-sf-symbol",
    "symbol": "applelogo",
    "note": "Rendered in-app via SF Symbols, no PNG file"
}
results["skipped"] += 1
print(f"  SKIP apple-tv — uses SF Symbol 'applelogo'")

# ── Write manifest ────────────────────────────────────────────────────────────
manifest["summary"] = {
    "teams_ok": sum(1 for v in manifest["teams"].values() if v["status"] == "ok"),
    "teams_missing": sum(1 for v in manifest["teams"].values() if v["status"] == "missing"),
    "streaming_ok": sum(1 for v in manifest["streaming"].values() if v["status"] == "ok"),
    "streaming_missing": sum(1 for v in manifest["streaming"].values() if v["status"] == "missing"),
    "streaming_skipped": sum(1 for v in manifest["streaming"].values() if v["status"] not in ("ok","missing")),
}

manifest_path = os.path.join(OUT_DIR, "manifest.json")
with open(manifest_path, "w") as f:
    json.dump(manifest, f, indent=2)

print(f"""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Logo pipeline complete
  Teams     OK: {manifest['summary']['teams_ok']}  Missing: {manifest['summary']['teams_missing']}
  Streaming OK: {manifest['summary']['streaming_ok']}  Missing: {manifest['summary']['streaming_missing']}  Skipped: {manifest['summary']['streaming_skipped']}
  Manifest: {manifest_path}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
""")
