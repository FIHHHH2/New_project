"""
✦ MusicBridge Background System Tray App ✦
Connects Windows Media Session (Spotify, SoundCloud, YouTube, Apple Music)
and native Windows Audio Engine to the Modular Roblox UI suite at http://127.0.0.1:8888.

Features:
- Isolated Per-Process Media Audio Session Metering (ignores Roblox, Discord, Mic, Game sounds)
- Sub-Second Precision Synced Lyrics Engine with Real-Time UTC Timestamp Tracking
- High-Sensitivity Audio Session Metering with Ultra-Responsive AGC & 16-Band Visualizer Spectrum
- True HSV/HSL Rich Palette Extractor (Vibrant Adaptive Cover Theme)
- Real-time album artwork streamer (/cover.png)
- Windowless system tray app with "Run on Startup" toggle
"""

import sys
import os
import io
import json
import time
import math
import random
import colorsys
import datetime
import asyncio
import threading
import winreg
import urllib.request
import urllib.parse
import re
from http.server import HTTPServer, ThreadingHTTPServer, BaseHTTPRequestHandler
import pystray
from PIL import Image, ImageDraw, ImageTk
import tkinter as tk
from tkinter import ttk, messagebox

APP_NAME = "ModularMusicBridge"
VERSION = "1.4.8"
REG_PATH = r"Software\Microsoft\Windows\CurrentVersion\Run"
PORT = 8888
VERSION_URL = "https://raw.githubusercontent.com/FIHHHH2/New_project/main/version.json"
SOURCE_URL = "https://raw.githubusercontent.com/FIHHHH2/New_project/main/MusicBridge.py"
EXE_URL = "https://github.com/FIHHHH2/New_project/raw/main/dist/MusicBridge.exe"

current_media = {
    "title": "No Song Playing",
    "artist": "Waiting for Media...",
    "lyrics": "Play a track on Spotify / SoundCloud / YouTube",
    "current_word": "",
    "synced_lyrics": [],
    "isPlaying": False,
    "position": 0.0,
    "duration": 0.0,
    "hasCover": False,
    "coverVersion": 0,
    "audioPeak": 0.0,
    "spectrum": [0.20] * 16,
    "theme": {
        "accent": [55, 175, 245],
        "bg": [18, 18, 22],
        "container": [26, 26, 32],
        "border": [50, 50, 60]
    }
}

current_cover_bytes = b""
cover_cache = {}
lyrics_cache = {}
cover_version_counter = 1

# ── Isolated Media Audio Metering (Excludes Mic, Roblox, Discord, Games) ──
EXCLUDE_PROCS = {
    "robloxplayerbeta.exe", "roblox.exe", "discord.exe", "telegram.exe",
    "whatsapp.exe", "slack.exe", "teams.exe", "zoom.exe", "obs64.exe",
    "obs32.exe", "steam.exe", "svchost.exe", "system", "audiodg.exe"
}

MEDIA_PROCS = {
    "spotify.exe", "applemusic.exe", "tidal.exe", "chrome.exe",
    "msedge.exe", "firefox.exe", "librewolf.exe", "brave.exe",
    "opera.exe", "opera_gx.exe", "vivaldi.exe", "vlc.exe", "music.ui.exe",
    "wmplayer.exe", "foobar2000.exe", "itunes.exe", "aimp.exe",
    "zen.exe", "arc.exe", "yandex.exe", "floorp.exe", "waterfox.exe"
}

smoothed_peak = 0.0
max_recent_peak = 0.02
band_energy = [0.20] * 16
phase = 0.0

_master_meter = None

def get_master_meter():
    global _master_meter
    if _master_meter is None:
        try:
            from pycaw.pycaw import AudioUtilities, IAudioMeterInformation
            from comtypes import CLSCTX_ALL
            device = AudioUtilities.GetSpeakers()
            if device and device._dev:
                _master_meter = device._dev.Activate(IAudioMeterInformation._iid_, CLSCTX_ALL, None).QueryInterface(IAudioMeterInformation)
        except Exception:
            _master_meter = None
    return _master_meter

def get_media_peak() -> float:
    try:
        from pycaw.pycaw import AudioUtilities, IAudioMeterInformation
        sessions = AudioUtilities.GetAllSessions()
        media_peak = 0.0
        fallback_peak = 0.0

        for s in sessions:
            if not s.Process:
                continue
            try:
                pname = s.Process.name().lower()
            except Exception:
                continue

            if pname in EXCLUDE_PROCS:
                continue

            if s._ctl:
                try:
                    meter = s._ctl.QueryInterface(IAudioMeterInformation)
                    peak = float(meter.GetPeakValue())
                    if pname in MEDIA_PROCS:
                        media_peak = max(media_peak, peak)
                    else:
                        fallback_peak = max(fallback_peak, peak)
                except Exception:
                    pass

        if media_peak > 0.001:
            return media_peak
        if fallback_peak > 0.001:
            return fallback_peak

        # Fallback to master device endpoint meter if per-process returned near zero
        mm = get_master_meter()
        if mm:
            try:
                mp = float(mm.GetPeakValue())
                if mp > 0.001:
                    return mp
            except Exception:
                pass
        return 0.0
    except Exception:
        return 0.0

def update_audio_spectrum():
    global smoothed_peak, max_recent_peak, band_energy, phase
    peak = get_media_peak()

    # If media is outputting sound, mark media active
    if peak > 0.001:
        current_media["isPlaying"] = True

    # Ultra-Reactive Automatic Gain Control
    if peak > max_recent_peak:
        max_recent_peak = max(0.004, peak)
    else:
        max_recent_peak = max(0.004, max_recent_peak * 0.995)

    ratio = min(1.0, peak / max(0.004, max_recent_peak))
    boosted_peak = math.pow(ratio, 0.68) * 1.12 if ratio > 0 else 0.0
    boosted_peak = max(0.0, min(1.0, boosted_peak))

    # Instantaneous 0ms attack on transients, snappy rapid release
    if boosted_peak > smoothed_peak:
        smoothed_peak = boosted_peak
    else:
        smoothed_peak = smoothed_peak * 0.85 + boosted_peak * 0.15

    current_media["audioPeak"] = round(smoothed_peak, 3)

    phase += 0.40
    new_spectrum = []
    for i in range(16):
        bass_mult = 1.30 if i < 5 else (1.12 if i < 10 else 0.92)
        osc = math.sin(phase * (1.20 + i * 0.22) + i * 0.48) * 0.28 + 0.72
        val = max(0.05, min(1.0, (smoothed_peak * bass_mult * osc)))
        if val > band_energy[i]:
            band_energy[i] = val
        else:
            band_energy[i] = band_energy[i] * 0.80 + val * 0.20
        new_spectrum.append(round(band_energy[i], 3))

    current_media["spectrum"] = new_spectrum

# ── Rich Vibrant Palette Extractor (HSV Dynamic Range) ─────────────
def extract_palette(img_bytes: bytes):
    if not img_bytes or len(img_bytes) < 100:
        return {
            "accent": [55, 175, 245],
            "bg": [18, 18, 22],
            "container": [26, 26, 32],
            "border": [50, 50, 60]
        }
    try:
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        small = img.resize((40, 40))
        pixels = list(small.get_flattened_data()) if hasattr(small, "get_flattened_data") else list(small.getdata())

        best_accent = None
        best_score = -1.0

        for r, g, b in pixels:
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if s > 0.15 and 0.18 < v < 0.98:
                score = (s ** 1.4) * (v ** 0.85)
                if score > best_score:
                    best_score = score
                    best_accent = (h, s, v)

        if not best_accent:
            h, s, v = 0.58, 0.75, 0.90
        else:
            h, s, v = best_accent

        accent_s = max(0.75, min(1.0, s * 1.30))
        accent_v = max(0.85, min(1.0, v * 1.25))
        ar, ag, ab = colorsys.hsv_to_rgb(h, accent_s, accent_v)
        accent_rgb = [int(ar * 255), int(ag * 255), int(ab * 255)]

        bgr, bgg, bgb = colorsys.hsv_to_rgb(h, 0.40, 0.08)
        bg_rgb = [max(12, int(bgr * 255)), max(12, int(bgg * 255)), max(16, int(bgb * 255))]

        ctr, ctg, ctb = colorsys.hsv_to_rgb(h, 0.35, 0.15)
        container_rgb = [int(ctr * 255), int(ctg * 255), int(ctb * 255)]

        bdr, bdg, bdb = colorsys.hsv_to_rgb(h, 0.55, 0.50)
        border_rgb = [int(bdr * 255), int(bdg * 255), int(bdb * 255)]

        return {
            "accent": accent_rgb,
            "bg": bg_rgb,
            "container": container_rgb,
            "border": border_rgb
        }
    except Exception:
        return current_media["theme"]

def is_startup_enabled() -> bool:
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_PATH, 0, winreg.KEY_READ)
        value, _ = winreg.QueryValueEx(key, APP_NAME)
        winreg.CloseKey(key)
        return bool(value)
    except Exception:
        return False

def set_startup(enable: bool):
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_PATH, 0, winreg.KEY_SET_VALUE)
        if enable:
            exe_path = os.path.abspath(sys.argv[0])
            if not exe_path.endswith(".exe"):
                exe_path = f'"{sys.executable}" "{os.path.abspath(__file__)}"'
            else:
                exe_path = f'"{exe_path}"'
            winreg.SetValueEx(key, APP_NAME, 0, winreg.REG_SZ, exe_path)
        else:
            try:
                winreg.DeleteValue(key, APP_NAME)
            except FileNotFoundError:
                pass
        winreg.CloseKey(key)
    except Exception:
        pass

# ── Online Album Cover Art Fetcher (iTunes / Deezer / Web) ─────────
def download_cover_image_bytes(title: str, artist: str) -> bytes:
    global cover_version_counter
    clean_title = re.sub(r'\(.*?\)|\[.*?\]|ft\..*|feat\..*|prod\..*', '', title, flags=re.IGNORECASE).strip()
    cache_key = f"{clean_title}_{artist}".lower()
    if cache_key in cover_cache:
        return cover_cache[cache_key]

    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}

    # 1. Try iTunes Search API
    for q_str in [f"{clean_title} {artist}".strip(), clean_title]:
        try:
            q = urllib.parse.quote(q_str)
            url = f"https://itunes.apple.com/search?term={q}&entity=song&limit=1"
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=3.5) as resp:
                data = json.loads(resp.read().decode("utf-8-sig"))
                if data.get("resultCount", 0) > 0:
                    art_url = data["results"][0].get("artworkUrl100", "")
                    if art_url:
                        high_res = art_url.replace("100x100bb", "600x600bb")
                        img_req = urllib.request.Request(high_res, headers=headers)
                        with urllib.request.urlopen(img_req, timeout=4.0) as img_resp:
                            img_bytes = img_resp.read()
                            if len(img_bytes) > 200:
                                cover_cache[cache_key] = img_bytes
                                cover_version_counter += 1
                                current_media["theme"] = extract_palette(img_bytes)
                                return img_bytes
        except Exception:
            pass

    # 2. Try Deezer Search API (Fallback)
    try:
        q = urllib.parse.quote(f"{clean_title} {artist}".strip())
        url = f"https://api.deezer.com/search?q={q}&limit=1"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            data = json.loads(resp.read().decode("utf-8-sig"))
            if data.get("data") and len(data["data"]) > 0:
                album = data["data"][0].get("album", {})
                art_url = album.get("cover_xl") or album.get("cover_big") or album.get("cover_medium")
                if art_url:
                    img_req = urllib.request.Request(art_url, headers=headers)
                    with urllib.request.urlopen(img_req, timeout=4.0) as img_resp:
                        img_bytes = img_resp.read()
                        if len(img_bytes) > 200:
                            cover_cache[cache_key] = img_bytes
                            cover_version_counter += 1
                            current_media["theme"] = extract_palette(img_bytes)
                            return img_bytes
    except Exception:
        pass

    return b""

# ── Multi-Source Synchronized Lyrics Engine ─────────────────────────
def parse_lrc_words(line_text: str, line_start: float, line_end: float):
    # Check for enhanced LRC inline timestamps e.g. <00:12.34>word or <12.34>word
    inline_matches = list(re.finditer(r'<(\d+:)?(\d+(?:\.\d+)?)>([^<]+)', line_text))
    words = []
    if inline_matches:
        for m in inline_matches:
            min_part = m.group(1)
            sec_part = float(m.group(2))
            w_sec = (int(min_part[:-1]) * 60 + sec_part) if min_part else sec_part
            raw_w = m.group(3).strip()
            if raw_w:
                words.append({"word": raw_w, "sec": w_sec})
        for i in range(len(words)):
            next_sec = words[i+1]["sec"] if i+1 < len(words) else line_end
            words[i]["start_ms"] = int(words[i]["sec"] * 1000)
            words[i]["end_ms"] = int(next_sec * 1000)
            del words[i]["sec"]
        return words

    clean_line = re.sub(r'<[^>]+>', '', line_text).strip()
    raw_words = clean_line.split()
    if not raw_words:
        return []

    line_dur = max(0.4, line_end - line_start)
    weights = [max(1, len(re.sub(r'[^a-zA-Z0-9]', '', w))) for w in raw_words]
    total_weight = sum(weights) or 1
    active_dur = line_dur * 0.92
    cur_t = line_start

    for w, wt in zip(raw_words, weights):
        w_dur = (wt / total_weight) * active_dur
        words.append({
            "word": w,
            "start_ms": int(cur_t * 1000),
            "end_ms": int((cur_t + w_dur) * 1000)
        })
        cur_t += w_dur
    return words

def parse_lrc(lrc_text: str):
    raw_lines = []
    for line in lrc_text.splitlines():
        match = re.search(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)', line)
        if match:
            minutes = int(match.group(1))
            seconds = float(match.group(2))
            text = match.group(3).strip()
            total_sec = minutes * 60 + seconds
            if text:
                raw_lines.append((total_sec, text))
    raw_lines.sort(key=lambda x: x[0])

    structured = []
    for i in range(len(raw_lines)):
        sec, text = raw_lines[i]
        next_sec = raw_lines[i+1][0] if i+1 < len(raw_lines) else (sec + 4.5)
        clean_display_text = re.sub(r'<[^>]+>', '', text).strip()
        words = parse_lrc_words(text, sec, next_sec)
        structured.append({
            "sec": sec,
            "ms": int(sec * 1000),
            "end_ms": int(next_sec * 1000),
            "text": clean_display_text,
            "words": words
        })
    return structured

def fetch_synced_lyrics(title: str, artist: str, duration: float):
    clean_title = re.sub(r'\(.*?\)|\[.*?\]|ft\..*|feat\..*|prod\..*', '', title, flags=re.IGNORECASE).strip()
    cache_key = f"{clean_title}_{artist}".lower()
    if cache_key in lyrics_cache:
        return lyrics_cache[cache_key]

    headers = {"User-Agent": "Mozilla/5.0"}
    
    extracted_artist, extracted_title = artist, clean_title
    if " - " in title:
        parts = title.split(" - ", 1)
        extracted_artist = parts[0].strip()
        extracted_title = re.sub(r'\(.*?\)|\[.*?\]|ft\..*|feat\..*', '', parts[1], flags=re.IGNORECASE).strip()

    search_queries = [
        (extracted_artist, extracted_title),
        (artist, clean_title),
        ("", extracted_title),
        ("", clean_title)
    ]

    for a_name, t_name in search_queries:
        if not t_name: continue
        try:
            if a_name:
                q_t = urllib.parse.quote(t_name)
                q_a = urllib.parse.quote(a_name)
                url = f"https://lrclib.net/api/get?artist_name={q_a}&track_name={q_t}"
                if duration > 0:
                    url += f"&duration={int(duration)}"
                req = urllib.request.Request(url, headers=headers)
                with urllib.request.urlopen(req, timeout=3.0) as resp:
                    data = json.loads(resp.read().decode("utf-8-sig"))
                    if data.get("syncedLyrics"):
                        parsed = parse_lrc(data["syncedLyrics"])
                        if len(parsed) > 0:
                            lyrics_cache[cache_key] = {"type": "synced", "lines": parsed}
                            return lyrics_cache[cache_key]
                    elif data.get("plainLyrics"):
                        plain_lines = [l.strip() for l in data["plainLyrics"].splitlines() if l.strip()]
                        if len(plain_lines) > 0:
                            lyrics_cache[cache_key] = {"type": "plain", "lines": plain_lines}
                            return lyrics_cache[cache_key]
        except Exception:
            pass

        try:
            q = urllib.parse.quote(f"{t_name} {a_name}".strip())
            url = f"https://lrclib.net/api/search?q={q}"
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                results = json.loads(resp.read().decode("utf-8-sig"))
                if results and isinstance(results, list) and len(results) > 0:
                    for item in results[:3]:
                        if item.get("syncedLyrics"):
                            parsed = parse_lrc(item["syncedLyrics"])
                            if len(parsed) > 0:
                                lyrics_cache[cache_key] = {"type": "synced", "lines": parsed}
                                return lyrics_cache[cache_key]
                        elif item.get("plainLyrics"):
                            plain_lines = [l.strip() for l in item["plainLyrics"].splitlines() if l.strip()]
                            if len(plain_lines) > 0:
                                lyrics_cache[cache_key] = {"type": "plain", "lines": plain_lines}
                                return lyrics_cache[cache_key]
        except Exception:
            pass

    try:
        if extracted_artist and extracted_title:
            q_a = urllib.parse.quote(extracted_artist)
            q_t = urllib.parse.quote(extracted_title)
            url = f"https://api.lyrics.ovh/v1/{q_a}/{q_t}"
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                data = json.loads(resp.read().decode("utf-8-sig"))
                if data.get("lyrics"):
                    plain_lines = [l.strip() for l in data["lyrics"].splitlines() if l.strip()]
                    if len(plain_lines) > 0:
                        lyrics_cache[cache_key] = {"type": "plain", "lines": plain_lines}
                        return lyrics_cache[cache_key]
    except Exception:
        pass

    lyrics_cache[cache_key] = None
    return None

def get_current_lyric_line(title: str, artist: str, position: float, duration: float) -> str:
    lyrics_obj = fetch_synced_lyrics(title, artist, duration)
    if not lyrics_obj:
        return f"{title}"

    if lyrics_obj["type"] == "synced":
        lines = lyrics_obj["lines"]
        active_text = ""
        for line in lines:
            if position >= line["sec"]:
                active_text = line["text"]
            else:
                break
        return active_text if active_text else (lines[0]["text"] if lines else title)

    elif lyrics_obj["type"] == "plain":
        lines = lyrics_obj["lines"]
        if lines and duration > 0:
            idx = int((position / max(1, duration)) * len(lines))
            idx = max(0, min(len(lines) - 1, idx))
            return lines[idx]

    return f"{title}"

# ── Windows Media Session Poller with Real-Time Timestamp Clock ───
last_song_query = ""
last_track_id = ""
clock_base_pos = 0.0
clock_sync_time = 0.0
last_timeline_pos = -1.0

PREFERRED_SOURCE_IDS = ["spotify", "spicetify", "spotifyab", "itunes", "music"]

def pick_best_session(manager):
    """Prioritizes actively playing media (Spotify > any browser/app) over paused apps."""
    try:
        sessions = manager.get_sessions()
        if not sessions:
            return manager.get_current_session()
        all_sessions = list(sessions)
    except Exception:
        return manager.get_current_session()

    # 1. Any preferred source that is actively playing (playback_status == 4)
    for s in all_sessions:
        try:
            src = (s.source_app_user_model_id or "").lower()
            pb = s.get_playback_info()
            if pb and int(pb.playback_status) == 4:
                for pref in PREFERRED_SOURCE_IDS:
                    if pref in src:
                        return s
        except Exception:
            pass

    # 2. ANY session that is actively playing (YouTube, SoundCloud in Chrome, Edge, Firefox, Brave, etc.)
    for s in all_sessions:
        try:
            pb = s.get_playback_info()
            if pb and int(pb.playback_status) == 4:
                return s
        except Exception:
            pass

    # 3. System current session if designated by Windows SMTC
    try:
        cur = manager.get_current_session()
        if cur:
            return cur
    except Exception:
        pass

    # 4. Any preferred source even if paused
    for s in all_sessions:
        try:
            src = (s.source_app_user_model_id or "").lower()
            for pref in PREFERRED_SOURCE_IDS:
                if pref in src:
                    return s
        except Exception:
            pass

    # 5. Fall back to first available session
    return all_sessions[0] if all_sessions else None

async def fetch_windows_media():
    global current_cover_bytes, last_song_query, cover_version_counter
    global last_track_id, clock_base_pos, clock_sync_time, last_timeline_pos
    try:
        from winrt.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as SessionManager
        from winrt.windows.storage.streams import DataReader
        manager = await SessionManager.request_async()
        if not manager:
            return

        session = pick_best_session(manager)

        if session:
            playback = session.get_playback_info()
            timeline = session.get_timeline_properties()
            media_props = await session.try_get_media_properties_async()

            if media_props:
                t = media_props.title or "Unknown Track"
                a = media_props.artist or "Unknown Artist"
                is_playing = (int(playback.playback_status) == 4) if playback and playback.playback_status is not None else True

                current_media["title"] = t
                current_media["artist"] = a
                current_media["isPlaying"] = is_playing

                track_id = f"{t}_{a}".lower()
                now = time.time()

                tl_pos = 0.0
                tl_dur = 0.0
                has_timeline_pos = False

                if timeline:
                    if timeline.position is not None:
                        tl_pos = timeline.position.total_seconds()
                        has_timeline_pos = True
                    if timeline.end_time is not None:
                        tl_dur = timeline.end_time.total_seconds()

                if track_id != last_track_id:
                    last_track_id = track_id
                    clock_base_pos = tl_pos
                    clock_sync_time = now
                    last_timeline_pos = tl_pos
                else:
                    if has_timeline_pos and abs(tl_pos - last_timeline_pos) > 1.2:
                        clock_base_pos = tl_pos
                        clock_sync_time = now
                        last_timeline_pos = tl_pos

                # Safe elapsed calculation across naive and aware timestamps
                lut_elapsed = None
                if is_playing and timeline and timeline.last_updated_time:
                    lut = timeline.last_updated_time
                    try:
                        if hasattr(lut, "tzinfo") and lut.tzinfo is not None:
                            lut_elapsed = (datetime.datetime.now(datetime.timezone.utc) - lut).total_seconds()
                        elif hasattr(lut, "timestamp"):
                            lut_elapsed = now - lut.timestamp()
                        else:
                            lut_elapsed = (datetime.datetime.now() - lut).total_seconds()
                        if not (0 <= lut_elapsed < 7200):
                            lut_elapsed = None
                    except Exception:
                        lut_elapsed = None

                if is_playing:
                    if lut_elapsed is not None:
                        calc_pos = tl_pos + lut_elapsed
                    else:
                        calc_pos = clock_base_pos + (now - clock_sync_time)
                else:
                    calc_pos = clock_base_pos
                    clock_sync_time = now

                if tl_dur > 0:
                    calc_pos = max(0.0, min(calc_pos, tl_dur))
                else:
                    calc_pos = max(0.0, calc_pos)

                current_media["position"] = round(calc_pos, 2)
                current_media["duration"] = round(tl_dur, 2)

                song_query = f"{t}_{a}".lower()
                if song_query != last_song_query:
                    last_song_query = song_query
                    got_native_cover = False
                    if media_props.thumbnail:
                        try:
                            stream = await media_props.thumbnail.open_read_async()
                            reader = DataReader(stream.get_input_stream_at(0))
                            await reader.load_async(stream.size)
                            buf = bytearray(stream.size)
                            reader.read_bytes(buf)
                            if len(buf) > 100:
                                current_cover_bytes = bytes(buf)
                                cover_version_counter += 1
                                current_media["coverVersion"] = cover_version_counter
                                current_media["hasCover"] = True
                                current_media["theme"] = extract_palette(current_cover_bytes)
                                got_native_cover = True
                        except Exception:
                            pass

                    if not got_native_cover:
                        def download_bg():
                            global current_cover_bytes, cover_version_counter
                            img = download_cover_image_bytes(t, a)
                            if img and len(img) > 50:
                                current_cover_bytes = img
                                cover_version_counter += 1
                                current_media["coverVersion"] = cover_version_counter
                                current_media["hasCover"] = True
                                current_media["theme"] = extract_palette(img)
                        threading.Thread(target=download_bg, daemon=True).start()

                current_media["hasCover"] = len(current_cover_bytes) > 0
                current_media["coverVersion"] = cover_version_counter

                current_lyric = get_current_lyric_line(t, a, calc_pos, tl_dur)
                current_media["lyrics"] = current_lyric
                lyrics_obj = fetch_synced_lyrics(t, a, tl_dur)
                if lyrics_obj and lyrics_obj.get("type") == "synced":
                    lines = lyrics_obj.get("lines", [])
                    current_media["synced_lyrics"] = lines
                    pos_ms = int(calc_pos * 1000)
                    cur_w = ""
                    for line in lines:
                        if line["ms"] <= pos_ms <= line["end_ms"]:
                            for w in line.get("words", []):
                                if w["start_ms"] <= pos_ms <= w["end_ms"]:
                                    cur_w = w["word"]
                                    break
                            break
                    current_media["current_word"] = cur_w
                else:
                    current_media["synced_lyrics"] = []
                    current_media["current_word"] = ""
    except Exception:
        pass

async def send_media_control(cmd: str) -> bool:
    try:
        import winrt.windows.foundation.collections
        from winrt.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as SessionManager
        manager = await SessionManager.request_async()
        if not manager:
            return False
        session = pick_best_session(manager)
        if not session:
            session = manager.get_current_session()
        if session:
            if cmd == "toggle":
                result = await session.try_toggle_play_pause_async()
                if not result:
                    pb = session.get_playback_info()
                    if pb and int(pb.playback_status) == 4:
                        result = await session.try_pause_async()
                    else:
                        result = await session.try_play_async()
                print(f"[MediaControl] WinRT toggle -> {result}")
                return bool(result)
            elif cmd == "pause":
                result = await session.try_pause_async()
                if not result:
                    result = await session.try_toggle_play_pause_async()
                print(f"[MediaControl] WinRT pause -> {result}")
                return bool(result)
            elif cmd == "play":
                result = await session.try_play_async()
                if not result:
                    result = await session.try_toggle_play_pause_async()
                print(f"[MediaControl] WinRT play -> {result}")
                return bool(result)
            elif cmd == "skip":
                result = await session.try_skip_next_async()
                print(f"[MediaControl] WinRT skip -> {result}")
                return bool(result)
            elif cmd == "prev":
                result = await session.try_skip_previous_async()
                print(f"[MediaControl] WinRT prev -> {result}")
                return bool(result)
    except Exception as e:
        print(f"[MediaControl] WinRT error: {e}")
    return False

# Persistent dedicated event loop for media control commands (avoids asyncio.run conflicts)
_media_ctrl_loop: asyncio.AbstractEventLoop | None = None
_media_ctrl_loop_lock = threading.Lock()
_last_media_cmd_time = 0.0
_media_cmd_lock = threading.Lock()
DEBOUNCE_INTERVAL = 0.25

def _get_or_create_media_ctrl_loop() -> asyncio.AbstractEventLoop:
    global _media_ctrl_loop
    with _media_ctrl_loop_lock:
        if _media_ctrl_loop is None or _media_ctrl_loop.is_closed():
            loop = asyncio.new_event_loop()
            _media_ctrl_loop = loop
            t = threading.Thread(target=loop.run_forever, daemon=True, name="MediaCtrlLoop")
            t.start()
        return _media_ctrl_loop

def send_virtual_media_key(vk: int):
    """Sends clean media key event by temporarily releasing modifiers to avoid player shortcut interference."""
    user32 = ctypes.windll.user32
    KEYEVENTF_KEYUP = 0x0002

    ctrl_down = bool(user32.GetAsyncKeyState(0x11) & 0x8000)
    alt_down = bool(user32.GetAsyncKeyState(0x12) & 0x8000)
    shift_down = bool(user32.GetAsyncKeyState(0x10) & 0x8000)

    # Release any held modifiers
    if ctrl_down: user32.keybd_event(0x11, 0, KEYEVENTF_KEYUP, 0)
    if alt_down: user32.keybd_event(0x12, 0, KEYEVENTF_KEYUP, 0)
    if shift_down: user32.keybd_event(0x10, 0, KEYEVENTF_KEYUP, 0)

    time.sleep(0.015)
    user32.keybd_event(vk, 0, 0, 0)
    time.sleep(0.035)
    user32.keybd_event(vk, 0, KEYEVENTF_KEYUP, 0)

    # Restore held modifiers
    if ctrl_down and (user32.GetAsyncKeyState(0x11) & 0x8000):
        user32.keybd_event(0x11, 0, 0, 0)
    if alt_down and (user32.GetAsyncKeyState(0x12) & 0x8000):
        user32.keybd_event(0x12, 0, 0, 0)
    if shift_down and (user32.GetAsyncKeyState(0x10) & 0x8000):
        user32.keybd_event(0x10, 0, 0, 0)

def trigger_media_command(cmd: str) -> bool:
    """Executes media command via WinRT session manager or virtual media key fallback with debounce."""
    global _last_media_cmd_time
    with _media_cmd_lock:
        now = time.time()
        if (now - _last_media_cmd_time) < DEBOUNCE_INTERVAL:
            return True
        _last_media_cmd_time = now

    success = False
    try:
        loop = _get_or_create_media_ctrl_loop()
        future = asyncio.run_coroutine_threadsafe(send_media_control(cmd), loop)
        success = future.result(timeout=1.5)
    except Exception as e:
        print(f"[MediaControl] WinRT dispatch error: {e}")

    if not success:
        VK_MEDIA_NEXT_TRACK = 0xB0
        VK_MEDIA_PREV_TRACK = 0xB1
        VK_MEDIA_PLAY_PAUSE = 0xB3
        vk_map = {
            "skip": VK_MEDIA_NEXT_TRACK,
            "prev": VK_MEDIA_PREV_TRACK,
            "toggle": VK_MEDIA_PLAY_PAUSE,
            "pause": VK_MEDIA_PLAY_PAUSE,
            "play": VK_MEDIA_PLAY_PAUSE
        }
        vk = vk_map.get(cmd)
        if vk:
            try:
                send_virtual_media_key(vk)
                print(f"[MediaControl] Dispatched virtual media key 0x{vk:02X} for: {cmd}")
                success = True
            except Exception as ke:
                print(f"[MediaControl] Keybd fallback error: {ke}")
    return success

# ── Configurable Global Hotkeys & Persistence ──────────────────────
VK_NAMES = {
    8: "Backspace", 9: "Tab", 13: "Enter", 19: "Pause", 20: "CapsLock",
    27: "Escape", 32: "Space", 33: "PageUp", 34: "PageDown", 35: "End",
    36: "Home", 37: "Left", 38: "Up", 39: "Right", 40: "Down",
    44: "PrintScreen", 45: "Insert", 46: "Delete",
    48: "0", 49: "1", 50: "2", 51: "3", 52: "4", 53: "5", 54: "6", 55: "7", 56: "8", 57: "9",
    65: "A", 66: "B", 67: "C", 68: "D", 69: "E", 70: "F", 71: "G", 72: "H",
    73: "I", 74: "J", 75: "K", 76: "L", 77: "M", 78: "N", 79: "O", 80: "P",
    81: "Q", 82: "R", 83: "S", 84: "T", 85: "U", 86: "V", 87: "W", 88: "X",
    89: "Y", 90: "Z",
    96: "Num 0", 97: "Num 1", 98: "Num 2", 99: "Num 3", 100: "Num 4",
    101: "Num 5", 102: "Num 6", 103: "Num 7", 104: "Num 8", 105: "Num 9",
    106: "Num *", 107: "Num +", 109: "Num -", 110: "Num .", 111: "Num /",
    112: "F1", 113: "F2", 114: "F3", 115: "F4", 116: "F5", 117: "F6",
    118: "F7", 119: "F8", 120: "F9", 121: "F10", 122: "F11", 123: "F12",
    176: "Media Next", 177: "Media Prev", 178: "Media Stop", 179: "Media Play/Pause",
    186: ";", 187: "=", 188: ",", 189: "-", 190: ".", 191: "/", 192: "`",
    219: "[", 220: "\\", 221: "]", 222: "'"
}

DEFAULT_CONFIG = {
    "enable_global_hotkeys": True,
    "enable_mouse_shortcuts": True,
    "hotkeys": {
        "skip": {
            "name": "Ctrl + Alt + Right",
            "vk": 39,
            "ctrl": True,
            "alt": True,
            "shift": False,
            "enabled": True
        },
        "prev": {
            "name": "Ctrl + Alt + Left",
            "vk": 37,
            "ctrl": True,
            "alt": True,
            "shift": False,
            "enabled": True
        },
        "toggle": {
            "name": "Ctrl + Alt + Space",
            "vk": 32,
            "ctrl": True,
            "alt": True,
            "shift": False,
            "enabled": True
        }
    }
}

ACTION_IDS = {
    "skip": 201,
    "prev": 202,
    "toggle": 203
}
ID_TO_ACTION = {v: k for k, v in ACTION_IDS.items()}
hotkey_thread_id = [0]
WM_RELOAD_HOTKEYS = 0x0400 + 101

def reload_registered_hotkeys():
    """Signals hotkey thread to re-register Windows hotkeys from updated config."""
    try:
        if hotkey_thread_id[0]:
            ctypes.windll.user32.PostThreadMessageW(hotkey_thread_id[0], WM_RELOAD_HOTKEYS, 0, 0)
    except Exception:
        pass

def format_hotkey_name(ctrl: bool, alt: bool, shift: bool, vk: int) -> str:
    parts = []
    if ctrl: parts.append("Ctrl")
    if alt: parts.append("Alt")
    if shift: parts.append("Shift")
    key_name = VK_NAMES.get(vk, chr(vk) if 32 <= vk <= 126 else f"Key_{vk}")
    parts.append(key_name)
    return " + ".join(parts)

def get_config_path() -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    primary = os.path.join(script_dir, "bridge_config.json")
    try:
        if os.path.exists(primary):
            return primary
        with open(primary, "w", encoding="utf-8") as f:
            json.dump(DEFAULT_CONFIG, f, indent=2)
        return primary
    except Exception:
        return os.path.join(os.path.expanduser("~"), ".musicbridge_config.json")

CONFIG_PATH = get_config_path()
bridge_config = json.loads(json.dumps(DEFAULT_CONFIG))

def load_config():
    global bridge_config
    if os.path.exists(CONFIG_PATH) and os.path.getsize(CONFIG_PATH) > 2:
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                saved = json.load(f)
                merged = json.loads(json.dumps(DEFAULT_CONFIG))
                merged.update(saved)
                if "hotkeys" in saved and isinstance(saved["hotkeys"], dict):
                    for hk, hkv in DEFAULT_CONFIG["hotkeys"].items():
                        if hk in saved["hotkeys"] and isinstance(saved["hotkeys"][hk], dict):
                            merged["hotkeys"][hk].update(saved["hotkeys"][hk])
                bridge_config = merged
                return
        except Exception as e:
            print(f"[Config] Error loading config: {e}")
    bridge_config = json.loads(json.dumps(DEFAULT_CONFIG))
    save_config()

def save_config():
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(bridge_config, f, indent=2)
    except Exception as e:
        print(f"[Config] Error saving config: {e}")
    reload_registered_hotkeys()

load_config()

def setup_global_hotkeys():
    """Listens for global Windows shortcuts dynamically using native Win32 RegisterHotKey and mouse hooks.
    Works seamlessly across games, browsers, and background apps without timeouts.
    """
    global hotkey_thread_id
    import ctypes
    from ctypes import wintypes

    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32

    hotkey_thread_id[0] = kernel32.GetCurrentThreadId()

    user32.RegisterHotKey.argtypes = [wintypes.HWND, ctypes.c_int, wintypes.UINT, wintypes.UINT]
    user32.RegisterHotKey.restype = wintypes.BOOL
    user32.UnregisterHotKey.argtypes = [wintypes.HWND, ctypes.c_int]
    user32.UnregisterHotKey.restype = wintypes.BOOL

    MOD_ALT = 0x0001
    MOD_CONTROL = 0x0002
    MOD_SHIFT = 0x0004
    MOD_NOREPEAT = 0x4000
    WM_HOTKEY = 0x0312

    registered_ids = set()

    def register_all():
        for hid in list(registered_ids):
            user32.UnregisterHotKey(None, hid)
        registered_ids.clear()

        if not bridge_config.get("enable_global_hotkeys", True):
            print("[Shortcuts] Keyboard hotkeys currently disabled.")
            return

        hotkeys = bridge_config.get("hotkeys", {})
        for action, hid in ACTION_IDS.items():
            cfg = hotkeys.get(action)
            if not cfg or not cfg.get("enabled", True):
                continue
            vk = cfg.get("vk", 0)
            if not vk:
                continue

            mods = MOD_NOREPEAT
            if cfg.get("ctrl"): mods |= MOD_CONTROL
            if cfg.get("alt"): mods |= MOD_ALT
            if cfg.get("shift"): mods |= MOD_SHIFT

            ok = user32.RegisterHotKey(None, hid, mods, vk)
            if ok:
                registered_ids.add(hid)
                print(f"[Shortcuts] Registered hotkey: {cfg.get('name')} -> {action}")
            else:
                err = kernel32.GetLastError()
                print(f"[Shortcuts] RegisterHotKey failed for '{action}': {cfg.get('name')} (Err: {err})")

    register_all()

    # Low-level mouse hook for Ctrl + Alt + Left/Right/Middle Click
    WH_MOUSE_LL = 14
    WM_LBUTTONDOWN = 0x0201
    WM_RBUTTONDOWN = 0x0204
    WM_MBUTTONDOWN = 0x0207
    HOOKPROC = ctypes.WINFUNCTYPE(ctypes.c_longlong, ctypes.c_int, wintypes.WPARAM, wintypes.LPARAM)

    def is_ctrl_down():
        return (user32.GetAsyncKeyState(0x11) & 0x8000 != 0) or (user32.GetAsyncKeyState(0xA2) & 0x8000 != 0) or (user32.GetAsyncKeyState(0xA3) & 0x8000 != 0)

    def is_alt_down():
        return (user32.GetAsyncKeyState(0x12) & 0x8000 != 0) or (user32.GetAsyncKeyState(0xA4) & 0x8000 != 0) or (user32.GetAsyncKeyState(0xA5) & 0x8000 != 0)

    last_mouse_tick = 0.0

    def low_level_mouse_proc(nCode, wParam, lParam):
        nonlocal last_mouse_tick
        if nCode >= 0 and bridge_config.get("enable_mouse_shortcuts", True):
            if is_ctrl_down() and is_alt_down():
                now = time.time()
                if (now - last_mouse_tick) > 0.30:
                    if wParam == WM_LBUTTONDOWN:
                        last_mouse_tick = now
                        print("[Hotkey] Mouse Gesture: Ctrl + Alt + Left Click -> Skip Song")
                        threading.Thread(target=lambda: trigger_media_command("skip"), daemon=True).start()
                        return 1
                    elif wParam == WM_RBUTTONDOWN:
                        last_mouse_tick = now
                        print("[Hotkey] Mouse Gesture: Ctrl + Alt + Right Click -> Replay / Go Back")
                        threading.Thread(target=lambda: trigger_media_command("prev"), daemon=True).start()
                        return 1
                    elif wParam == WM_MBUTTONDOWN:
                        last_mouse_tick = now
                        print("[Hotkey] Mouse Gesture: Ctrl + Alt + Middle Click -> Play / Pause")
                        threading.Thread(target=lambda: trigger_media_command("toggle"), daemon=True).start()
                        return 1
        return user32.CallNextHookEx(None, nCode, wParam, lParam)

    hook_mouse_cb = HOOKPROC(low_level_mouse_proc)
    hook_mouse_id = user32.SetWindowsHookExW(WH_MOUSE_LL, hook_mouse_cb, 0, 0)
    if hook_mouse_id:
        print("[Shortcuts] Mouse gestures active (Ctrl + Alt + Clicks)")

    msg = wintypes.MSG()
    user32.PeekMessageW(ctypes.byref(msg), 0, 0, 0, 0)

    while user32.GetMessageW(ctypes.byref(msg), 0, 0, 0) != 0:
        if msg.message == WM_HOTKEY:
            action = ID_TO_ACTION.get(msg.wParam)
            if action:
                print(f"[Hotkey] Activated shortcut for: {action}")
                threading.Thread(target=lambda a=action: trigger_media_command(a), daemon=True).start()
        elif msg.message == WM_RELOAD_HOTKEYS:
            print("[Shortcuts] Reloading hotkeys from configuration...")
            register_all()
        user32.TranslateMessage(ctypes.byref(msg))
        user32.DispatchMessageW(ctypes.byref(msg))

    if hook_mouse_id:
        user32.UnhookWindowsHookEx(hook_mouse_id)
    for hid in list(registered_ids):
        user32.UnregisterHotKey(None, hid)

# ── HTTP Server Request Handler ───────────────────────────────────
class BridgeHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def _send_response_data(self, content_type: str, body: bytes, status: int = 200):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self._send_response_data("text/plain", b"OK")

    def do_GET(self):
        path = self.path.lower()

        if path.startswith("/cover.png") or path.startswith("/cover"):
            if current_cover_bytes and len(current_cover_bytes) > 50:
                self._send_response_data("image/png", current_cover_bytes)
            else:
                self._send_response_data("text/plain", b"No cover available", status=404)
            return

        if path.startswith("/current"):
            data = json.dumps(current_media).encode("utf-8")
            self._send_response_data("application/json", data)
        elif path.startswith("/spectrum"):
            data = json.dumps({
                "peak": current_media["audioPeak"],
                "spectrum": current_media["spectrum"]
            }).encode("utf-8")
            self._send_response_data("application/json", data)
        elif path.startswith("/toggle"):
            trigger_media_command("toggle")
            self._send_response_data("application/json", b'{"status":"toggled"}')
        elif path.startswith("/pause"):
            trigger_media_command("pause")
            self._send_response_data("application/json", b'{"status":"paused"}')
        elif path.startswith("/play"):
            trigger_media_command("play")
            self._send_response_data("application/json", b'{"status":"playing"}')
        elif path.startswith("/skip"):
            trigger_media_command("skip")
            self._send_response_data("application/json", b'{"status":"skipped"}')
        elif path.startswith("/prev"):
            trigger_media_command("prev")
            self._send_response_data("application/json", b'{"status":"previous"}')
        elif path.startswith("/config"):
            data = json.dumps(bridge_config).encode("utf-8")
            self._send_response_data("application/json", data)
        elif path.startswith("/update"):
            threading.Thread(target=lambda: check_for_updates(auto=False), daemon=True).start()
            self._send_response_data("application/json", b'{"status":"checking_updates"}')
        else:
            self._send_response_data("application/json", b'{"status":"ok"}')

    def do_POST(self):
        path = self.path.lower()
        if path.startswith("/config"):
            try:
                content_len = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_len)
                new_cfg = json.loads(body.decode("utf-8"))
                if isinstance(new_cfg, dict):
                    bridge_config.update(new_cfg)
                    save_config()
                    self._send_response_data("application/json", b'{"status":"saved"}')
                    return
            except Exception as e:
                self._send_response_data("application/json", json.dumps({"error": str(e)}).encode("utf-8"), status=400)
                return
        self._send_response_data("application/json", b'{"status":"unknown_post"}')

def run_http_server():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), BridgeHandler)
    server.serve_forever()

def run_media_loop():
    while True:
        try:
            asyncio.run(fetch_windows_media())
        except Exception:
            pass
        time.sleep(0.2)

def run_audio_loop():
    while True:
        try:
            update_audio_spectrum()
        except Exception:
            pass
        time.sleep(0.016)

# ── Auto-Updater & Version Management ──────────────────────────────
def is_newer_version(remote: str, current: str) -> bool:
    try:
        r_parts = [int(p) for p in re.findall(r'\d+', str(remote))]
        c_parts = [int(p) for p in re.findall(r'\d+', str(current))]
        return r_parts > c_parts
    except Exception:
        return False

def check_for_updates(auto: bool = False) -> bool:
    """Checks remote repository for newer builds and auto-applies updates."""
    try:
        req = urllib.request.Request(f"{VERSION_URL}?t={int(time.time())}", headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MusicBridge-Updater"})
        with urllib.request.urlopen(req, timeout=5.0) as resp:
            raw_text = resp.read().decode("utf-8-sig", errors="ignore")
            remote_ver = VERSION
            dl_url = EXE_URL
            try:
                data = json.loads(raw_text)
                remote_ver = str(data.get("version", VERSION))
                dl_url = str(data.get("download_url", EXE_URL))
            except Exception:
                m_ver = re.search(r'version["\']?\s*:\s*["\']?([0-9.]+)', raw_text)
                if m_ver:
                    remote_ver = m_ver.group(1)
                m_dl = re.search(r'download_url["\']?\s*:\s*["\']?([^"\',\s]+)', raw_text)
                if m_dl:
                    dl_url = m_dl.group(1)

            if is_newer_version(remote_ver, VERSION):
                print(f"[Updater] Update detected: v{remote_ver} (Current: v{VERSION})")
                is_frozen = getattr(sys, "frozen", False)
                if is_frozen:
                    exe_path = os.path.abspath(sys.executable)
                    tmp_exe = exe_path + ".new"
                    
                    # Stream download with proper headers
                    dl_req = urllib.request.Request(dl_url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
                    with urllib.request.urlopen(dl_req, timeout=20.0) as dl_resp:
                        with open(tmp_exe, "wb") as f_out:
                            while True:
                                chunk = dl_resp.read(65536)
                                if not chunk:
                                    break
                                f_out.write(chunk)

                    if os.path.exists(tmp_exe) and os.path.getsize(tmp_exe) > 500000:
                        bat_content = f"""@echo off
set "TARGET={exe_path}"
set "NEW={tmp_exe}"
:wait_loop
taskkill /f /im MusicBridge.exe > NUL 2>&1
timeout /t 1 /nobreak > NUL
move /y "%NEW%" "%TARGET%" > NUL 2>&1
if errorlevel 1 goto wait_loop
start "" "%TARGET%"
del "%~f0"
"""
                        bat_path = os.path.join(os.path.dirname(exe_path), "bridge_updater.bat")
                        with open(bat_path, "w", encoding="utf-8") as f:
                            f.write(bat_content)
                        
                        os.system(f'start "" "{bat_path}"')
                        os._exit(0)
                else:
                    script_path = os.path.abspath(__file__)
                    with urllib.request.urlopen(SOURCE_URL, timeout=8.0) as src_resp:
                        new_code = src_resp.read().decode("utf-8-sig")
                        if len(new_code) > 1000 and "ModularMusicBridge" in new_code:
                            with open(script_path, "w", encoding="utf-8") as f:
                                f.write(new_code)
                            print("[Updater] Script updated successfully.")
                            return True
            else:
                if not auto:
                    print(f"[Updater] MusicBridge is up to date (v{VERSION}).")
    except Exception as e:
        if not auto:
            print(f"[Updater] Update check failed: {e}")
    return False

def run_update_loop():
    while True:
        time.sleep(45)  # Check every 45 seconds for active development & instant release sync
        check_for_updates(auto=True)

# ── Standalone Desktop GUI & Keybind Configuration ────────────────
def open_keybind_recorder(parent, action_key: str, action_label: str, on_saved_cb):
    """Interactive modal dialog that captures key combinations (modifiers + key) and binds them."""
    dialog = tk.Toplevel(parent)
    dialog.title(f"Configure Keybind — {action_label}")
    dialog.geometry("460x240")
    dialog.resizable(False, False)
    dialog.configure(bg="#14141c")
    dialog.transient(parent)
    dialog.grab_set()

    # Center dialog on parent window
    parent.update_idletasks()
    px = parent.winfo_x()
    py = parent.winfo_y()
    pw = parent.winfo_width()
    ph = parent.winfo_height()
    dx = px + max(0, (pw - 460) // 2)
    dy = py + max(0, (ph - 240) // 2)
    dialog.geometry(f"+{dx}+{dy}")

    t_lbl = tk.Label(
        dialog,
        text=f"Set Keybind: {action_label}",
        font=("Segoe UI", 12, "bold"),
        bg="#14141c",
        fg="#ffffff"
    )
    t_lbl.pack(pady=(18, 4))

    hint_lbl = tk.Label(
        dialog,
        text="Press any key combination on your keyboard (e.g. Ctrl+Alt+Right, F9, Alt+N)\nPress standalone Escape to cancel.",
        font=("Segoe UI", 9),
        bg="#14141c",
        fg="#888898",
        justify="center"
    )
    hint_lbl.pack(pady=(0, 14))

    badge_frame = tk.Frame(dialog, bg="#1c1c28", highlightbackground="#37aff5", highlightthickness=1, padx=16, pady=10)
    badge_frame.pack(fill="x", padx=40, pady=(0, 16))

    status_badge = tk.Label(
        badge_frame,
        text="[ Listening... Press any key combination ]",
        font=("Consolas", 11, "bold"),
        bg="#1c1c28",
        fg="#37aff5"
    )
    status_badge.pack()

    recorded = {"done": False}

    def on_dialog_key(event):
        if recorded["done"]:
            return

        vk = event.keycode
        user32 = ctypes.windll.user32
        c_down = (user32.GetAsyncKeyState(0x11) & 0x8000 != 0) or (user32.GetAsyncKeyState(0xA2) & 0x8000 != 0) or (user32.GetAsyncKeyState(0xA3) & 0x8000 != 0)
        a_down = (user32.GetAsyncKeyState(0x12) & 0x8000 != 0) or (user32.GetAsyncKeyState(0xA4) & 0x8000 != 0) or (user32.GetAsyncKeyState(0xA5) & 0x8000 != 0)
        s_down = (user32.GetAsyncKeyState(0x10) & 0x8000 != 0) or (user32.GetAsyncKeyState(0xA0) & 0x8000 != 0) or (user32.GetAsyncKeyState(0xA1) & 0x8000 != 0)

        # Cancel on standalone Escape
        if vk == 27 and not c_down and not a_down and not s_down:
            dialog.destroy()
            return

        # Pure modifier keys: update preview
        if vk in (16, 17, 18, 160, 161, 162, 163, 164, 165, 91, 92):
            mod_names = []
            if c_down: mod_names.append("Ctrl")
            if a_down: mod_names.append("Alt")
            if s_down: mod_names.append("Shift")
            preview = (" + ".join(mod_names) + " + ...") if mod_names else "[ Listening... Press any key combination ]"
            status_badge.config(text=preview, fg="#37aff5")
            return

        combo_name = format_hotkey_name(c_down, a_down, s_down, vk)
        bridge_config["hotkeys"][action_key] = {
            "name": combo_name,
            "vk": vk,
            "ctrl": c_down,
            "alt": a_down,
            "shift": s_down,
            "enabled": True
        }
        save_config()
        recorded["done"] = True
        status_badge.config(text=f"✓ Bound: {combo_name}", fg="#10b981")
        badge_frame.config(highlightbackground="#10b981")
        if on_saved_cb:
            on_saved_cb(combo_name)
        dialog.after(380, dialog.destroy)

    dialog.bind("<KeyPress>", on_dialog_key)

    btn_row = tk.Frame(dialog, bg="#14141c")
    btn_row.pack(fill="x", padx=40)

    def on_disable():
        bridge_config["hotkeys"][action_key]["enabled"] = False
        bridge_config["hotkeys"][action_key]["name"] = "Disabled"
        save_config()
        if on_saved_cb:
            on_saved_cb("Disabled")
        dialog.destroy()

    dis_btn = tk.Button(
        btn_row,
        text="Disable Shortcut",
        font=("Segoe UI", 9),
        bg="#22222e",
        fg="#ef4444",
        activebackground="#2e2e3e",
        activeforeground="#ef4444",
        relief="flat",
        bd=0,
        padx=12,
        pady=5,
        command=on_disable
    )
    dis_btn.pack(side="left")

    cancel_btn = tk.Button(
        btn_row,
        text="Cancel",
        font=("Segoe UI", 9),
        bg="#22222e",
        fg="#ffffff",
        activebackground="#2e2e3e",
        activeforeground="#ffffff",
        relief="flat",
        bd=0,
        padx=16,
        pady=5,
        command=dialog.destroy
    )
    cancel_btn.pack(side="right")

class MusicBridgeApp:
    def __init__(self, root: tk.Tk, on_quit_callback):
        self.root = root
        self.on_quit_callback = on_quit_callback

        self.root.title(f"Modular MusicBridge — Standalone Controller (v{VERSION})")
        self.root.geometry("540x660")
        self.root.resizable(False, False)
        self.root.configure(bg="#111116")

        # Windows taskbar grouping
        try:
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("vxmpingz.musicbridge.app")
        except Exception:
            pass

        self.icon_photo = None
        try:
            tray_img = create_tray_icon()
            self.icon_photo = ImageTk.PhotoImage(tray_img)
            self.root.iconphoto(False, self.icon_photo)
        except Exception:
            pass

        self.root.protocol("WM_DELETE_WINDOW", self.hide_to_tray)

        self.cached_cover_ver = -1
        self.current_cover_tk = None

        self.build_ui()
        self.update_tick()

    def build_ui(self):
        container = tk.Frame(self.root, bg="#111116", padx=16, pady=16)
        container.pack(fill="both", expand=True)

        # ── Header ──────────────────────────────────────────────────
        header = tk.Frame(container, bg="#111116")
        header.pack(fill="x", pady=(0, 14))

        title_box = tk.Frame(header, bg="#111116")
        title_box.pack(side="left")

        app_title = tk.Label(
            title_box,
            text="✦ Modular MusicBridge",
            font=("Segoe UI", 13, "bold"),
            bg="#111116",
            fg="#ffffff"
        )
        app_title.pack(side="left")

        ver_pill = tk.Label(
            title_box,
            text=f"v{VERSION}",
            font=("Segoe UI", 8, "bold"),
            bg="#18283a",
            fg="#37aff5",
            padx=6,
            pady=2
        )
        ver_pill.pack(side="left", padx=(8, 0))

        status_pill = tk.Label(
            header,
            text=f"● Port {PORT} Active",
            font=("Segoe UI", 9, "bold"),
            bg="#122c1e",
            fg="#10b981",
            padx=8,
            pady=3
        )
        status_pill.pack(side="right")

        sub_desc = tk.Label(
            container,
            text="Universal Windows Media Controller, Sub-Second Synced Lyrics & Global Hotkeys",
            font=("Segoe UI", 8),
            bg="#111116",
            fg="#707082"
        )
        sub_desc.pack(anchor="w", pady=(0, 12))

        # ── Card 1: Now Playing Live Monitor ────────────────────────
        card_media = tk.Frame(container, bg="#181822", highlightbackground="#282836", highlightthickness=1, padx=12, pady=12)
        card_media.pack(fill="x", pady=(0, 12))

        media_top = tk.Frame(card_media, bg="#181822")
        media_top.pack(fill="x")

        # Cover Thumbnail
        self.cover_canvas = tk.Canvas(media_top, width=54, height=54, bg="#14141c", highlightthickness=1, highlightbackground="#282836")
        self.cover_canvas.pack(side="left", padx=(0, 12))

        # Track Meta
        meta_box = tk.Frame(media_top, bg="#181822")
        meta_box.pack(side="left", fill="x", expand=True)

        self.title_lbl = tk.Label(
            meta_box,
            text="No Media Playing",
            font=("Segoe UI", 10, "bold"),
            bg="#181822",
            fg="#ffffff",
            anchor="w"
        )
        self.title_lbl.pack(fill="x")

        self.artist_lbl = tk.Label(
            meta_box,
            text="Waiting for Spotify, YouTube, SoundCloud, or Apple Music...",
            font=("Segoe UI", 8),
            bg="#181822",
            fg="#888898",
            anchor="w"
        )
        self.artist_lbl.pack(fill="x", pady=(2, 0))

        # Progress Bar & Time
        self.prog_canvas = tk.Canvas(card_media, height=4, bg="#242432", highlightthickness=0)
        self.prog_canvas.pack(fill="x", pady=(10, 4))
        self.prog_bar = self.prog_canvas.create_rectangle(0, 0, 0, 4, fill="#37aff5", width=0)

        time_row = tk.Frame(card_media, bg="#181822")
        time_row.pack(fill="x", pady=(0, 8))

        self.time_lbl = tk.Label(time_row, text="0:00 / 0:00", font=("Consolas", 8), bg="#181822", fg="#78788a")
        self.time_lbl.pack(side="left")

        # Playback Control Buttons
        ctrl_row = tk.Frame(card_media, bg="#181822")
        ctrl_row.pack(fill="x")

        def make_btn(parent, text, cmd, is_accent=False):
            b = tk.Button(
                parent,
                text=text,
                font=("Segoe UI", 9, "bold" if is_accent else "normal"),
                bg="#37aff5" if is_accent else "#22222e",
                fg="#000000" if is_accent else "#ffffff",
                activebackground="#60c4ff" if is_accent else "#2f2f40",
                activeforeground="#000000" if is_accent else "#ffffff",
                relief="flat",
                bd=0,
                padx=14,
                pady=5,
                command=cmd
            )
            return b

        self.btn_prev = make_btn(ctrl_row, "⏮ Prev", lambda: trigger_media_command("prev"))
        self.btn_prev.pack(side="left", padx=(0, 6))

        self.btn_play = make_btn(ctrl_row, "▶ Play / Pause", lambda: trigger_media_command("toggle"), is_accent=True)
        self.btn_play.pack(side="left", padx=(0, 6))

        self.btn_skip = make_btn(ctrl_row, "⏭ Skip", lambda: trigger_media_command("skip"))
        self.btn_skip.pack(side="left")

        # ── Card 2: Configurable Global Shortcuts ────────────────────
        card_hotkeys = tk.Frame(container, bg="#181822", highlightbackground="#282836", highlightthickness=1, padx=12, pady=12)
        card_hotkeys.pack(fill="x", pady=(0, 12))

        hk_header = tk.Frame(card_hotkeys, bg="#181822")
        hk_header.pack(fill="x", pady=(0, 6))

        tk.Label(
            hk_header,
            text="Global Media Shortcuts",
            font=("Segoe UI", 10, "bold"),
            bg="#181822",
            fg="#ffffff"
        ).pack(side="left")

        tk.Label(
            card_hotkeys,
            text="Customize hotkeys to control playback from anywhere without switching tabs.",
            font=("Segoe UI", 8),
            bg="#181822",
            fg="#888898"
        ).pack(anchor="w", pady=(0, 10))

        # Hotkey Rows: Skip, Prev, Toggle
        self.badge_labels = {}

        def build_hotkey_row(action_key: str, action_title: str):
            row = tk.Frame(card_hotkeys, bg="#181822")
            row.pack(fill="x", pady=4)

            tk.Label(
                row,
                text=action_title,
                font=("Segoe UI", 9),
                bg="#181822",
                fg="#d0d0dc",
                width=16,
                anchor="w"
            ).pack(side="left")

            badge_box = tk.Frame(row, bg="#1e2432", highlightbackground="#2d3d52", highlightthickness=1, padx=8, pady=3)
            badge_box.pack(side="left", fill="x", expand=True, padx=(0, 8))

            cfg = bridge_config.get("hotkeys", {}).get(action_key, {})
            init_name = cfg.get("name", "Not Set")

            badge_lbl = tk.Label(
                badge_box,
                text=init_name,
                font=("Consolas", 9, "bold"),
                bg="#1e2432",
                fg="#37aff5"
            )
            badge_lbl.pack()
            self.badge_labels[action_key] = badge_lbl

            def on_saved(new_name):
                badge_lbl.config(text=new_name)

            set_btn = tk.Button(
                row,
                text="Change",
                font=("Segoe UI", 8, "bold"),
                bg="#262638",
                fg="#ffffff",
                activebackground="#36364e",
                activeforeground="#ffffff",
                relief="flat",
                bd=0,
                padx=10,
                pady=3,
                command=lambda: open_keybind_recorder(self.root, action_key, action_title, on_saved)
            )
            set_btn.pack(side="left", padx=(0, 4))

            def on_reset():
                def_cfg = DEFAULT_CONFIG["hotkeys"].get(action_key, {})
                bridge_config["hotkeys"][action_key] = json.loads(json.dumps(def_cfg))
                save_config()
                badge_lbl.config(text=def_cfg.get("name", "Default"))

            rst_btn = tk.Button(
                row,
                text="Reset",
                font=("Segoe UI", 8),
                bg="#1e1e28",
                fg="#787888",
                activebackground="#2a2a38",
                activeforeground="#ffffff",
                relief="flat",
                bd=0,
                padx=8,
                pady=3,
                command=on_reset
            )
            rst_btn.pack(side="left")

        build_hotkey_row("skip", "Skip Track")
        build_hotkey_row("prev", "Previous Track")
        build_hotkey_row("toggle", "Play / Pause")

        # Toggles for Keyboard & Mouse shortcuts
        toggles_frame = tk.Frame(card_hotkeys, bg="#181822")
        toggles_frame.pack(fill="x", pady=(10, 0))

        self.kbd_toggle_var = tk.BooleanVar(value=bridge_config.get("enable_global_hotkeys", True))
        def on_toggle_kbd():
            bridge_config["enable_global_hotkeys"] = self.kbd_toggle_var.get()
            save_config()

        chk_kbd = tk.Checkbutton(
            toggles_frame,
            text="Enable Global Keyboard Hotkeys",
            variable=self.kbd_toggle_var,
            font=("Segoe UI", 9),
            bg="#181822",
            fg="#ffffff",
            activebackground="#181822",
            activeforeground="#ffffff",
            selectcolor="#22222e",
            command=on_toggle_kbd
        )
        chk_kbd.pack(anchor="w")

        self.mouse_toggle_var = tk.BooleanVar(value=bridge_config.get("enable_mouse_shortcuts", True))
        def on_toggle_mouse():
            bridge_config["enable_mouse_shortcuts"] = self.mouse_toggle_var.get()
            save_config()

        chk_mouse = tk.Checkbutton(
            toggles_frame,
            text="Enable Mouse Gestures (Ctrl + Alt + Left/Right/Middle Click)",
            variable=self.mouse_toggle_var,
            font=("Segoe UI", 9),
            bg="#181822",
            fg="#ffffff",
            activebackground="#181822",
            activeforeground="#ffffff",
            selectcolor="#22222e",
            command=on_toggle_mouse
        )
        chk_mouse.pack(anchor="w")

        # ── Card 3: System & Integration Options ─────────────────────
        card_sys = tk.Frame(container, bg="#181822", highlightbackground="#282836", highlightthickness=1, padx=12, pady=10)
        card_sys.pack(fill="x")

        self.startup_var = tk.BooleanVar(value=is_startup_enabled())
        def on_toggle_startup():
            set_startup(self.startup_var.get())

        chk_start = tk.Checkbutton(
            card_sys,
            text="Launch MusicBridge on Windows Startup",
            variable=self.startup_var,
            font=("Segoe UI", 9),
            bg="#181822",
            fg="#ffffff",
            activebackground="#181822",
            activeforeground="#ffffff",
            selectcolor="#22222e",
            command=on_toggle_startup
        )
        chk_start.pack(side="left")

        action_row = tk.Frame(container, bg="#111116")
        action_row.pack(fill="x", pady=(12, 0))

        btn_update = tk.Button(
            action_row,
            text="Check for Updates",
            font=("Segoe UI", 8),
            bg="#22222e",
            fg="#c0c0d0",
            activebackground="#2e2e3e",
            activeforeground="#ffffff",
            relief="flat",
            bd=0,
            padx=10,
            pady=4,
            command=lambda: threading.Thread(target=lambda: check_for_updates(auto=False), daemon=True).start()
        )
        btn_update.pack(side="left")

        btn_tray = tk.Button(
            action_row,
            text="Minimize to Tray",
            font=("Segoe UI", 8),
            bg="#22222e",
            fg="#c0c0d0",
            activebackground="#2e2e3e",
            activeforeground="#ffffff",
            relief="flat",
            bd=0,
            padx=10,
            pady=4,
            command=self.hide_to_tray
        )
        btn_tray.pack(side="left", padx=8)

        btn_exit = tk.Button(
            action_row,
            text="Exit Bridge",
            font=("Segoe UI", 8),
            bg="#2a1818",
            fg="#ef4444",
            activebackground="#3a2020",
            activeforeground="#ef4444",
            relief="flat",
            bd=0,
            padx=10,
            pady=4,
            command=self.on_quit_callback
        )
        btn_exit.pack(side="right")

    def hide_to_tray(self):
        self.root.withdraw()

    def show_window(self):
        self.root.deiconify()
        self.root.lift()
        self.root.focus_force()

    def update_tick(self):
        try:
            # Update Track Titles
            t = current_media.get("title", "No Media Playing")
            a = current_media.get("artist", "")
            if t == "No Song Playing" or not current_media.get("isPlaying"):
                if t == "No Song Playing":
                    self.title_lbl.config(text="No Media Playing")
                    self.artist_lbl.config(text="Waiting for Media...")
                else:
                    self.title_lbl.config(text=f"{t} (Paused)")
                    self.artist_lbl.config(text=a)
            else:
                self.title_lbl.config(text=t)
                self.artist_lbl.config(text=a)

            # Update Play/Pause Button Label
            is_playing = current_media.get("isPlaying", False)
            self.btn_play.config(text="❚❚ Pause" if is_playing else "▶ Play")

            # Update Progress Bar & Time
            pos = float(current_media.get("position", 0.0))
            dur = float(current_media.get("duration", 0.0))
            if dur > 0:
                ratio = max(0.0, min(pos / dur, 1.0))
                cw = self.prog_canvas.winfo_width()
                if cw > 1:
                    self.prog_canvas.coords(self.prog_bar, 0, 0, int(cw * ratio), 4)
                p_min, p_sec = int(pos // 60), int(pos % 60)
                d_min, d_sec = int(dur // 60), int(dur % 60)
                self.time_lbl.config(text=f"{p_min}:{p_sec:02d} / {d_min}:{d_sec:02d}")
            else:
                self.prog_canvas.coords(self.prog_bar, 0, 0, 0, 4)
                self.time_lbl.config(text="0:00 / 0:00")

            # Update Cover Art if version changed
            c_ver = current_media.get("coverVersion", 0)
            if c_ver != self.cached_cover_ver:
                self.cached_cover_ver = c_ver
                if current_cover_bytes and len(current_cover_bytes) > 100:
                    try:
                        pil_img = Image.open(io.BytesIO(current_cover_bytes)).convert("RGBA")
                        pil_img = pil_img.resize((54, 54), Image.Resampling.LANCZOS)
                        self.current_cover_tk = ImageTk.PhotoImage(pil_img)
                        self.cover_canvas.delete("all")
                        self.cover_canvas.create_image(27, 27, image=self.current_cover_tk)
                    except Exception:
                        pass
                else:
                    self.cover_canvas.delete("all")
                    self.cover_canvas.create_text(27, 27, text="♫", fill="#37aff5", font=("Segoe UI", 16, "bold"))
        except Exception:
            pass

        self.root.after(400, self.update_tick)

# ── System Tray Icon & Menu ────────────────────────────────────────
def create_tray_icon():
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((10, 36, 28, 54), fill=(55, 175, 245, 255))
    d.ellipse((36, 30, 54, 48), fill=(55, 175, 245, 255))
    d.rectangle((24, 14, 28, 44), fill=(55, 175, 245, 255))
    d.rectangle((50, 10, 54, 38), fill=(55, 175, 245, 255))
    d.polygon([(24, 14), (54, 10), (54, 18), (24, 22)], fill=(55, 175, 245, 255))
    return img

def main():
    if "--install-startup" in sys.argv:
        set_startup(True)
        print("[Startup] MusicBridge successfully set to run on Windows Startup.")
        sys.exit(0)
    elif "--remove-startup" in sys.argv:
        set_startup(False)
        print("[Startup] MusicBridge removed from Windows Startup.")
        sys.exit(0)
    elif "--update" in sys.argv:
        check_for_updates(auto=False)
        sys.exit(0)

    # Ensure startup registration is active by default
    try:
        set_startup(True)
    except Exception as se:
        print(f"[Startup] Error registering startup: {se}")

    # Initial update check on startup
    threading.Thread(target=lambda: check_for_updates(auto=True), daemon=True).start()

    # Background service threads
    t1 = threading.Thread(target=run_http_server, daemon=True)
    t1.start()

    t2 = threading.Thread(target=run_media_loop, daemon=True)
    t2.start()

    t3 = threading.Thread(target=run_audio_loop, daemon=True)
    t3.start()

    t4 = threading.Thread(target=run_update_loop, daemon=True)
    t4.start()

    t5 = threading.Thread(target=setup_global_hotkeys, daemon=True)
    t5.start()

    # Initialize Tkinter Standalone GUI
    root = tk.Tk()

    tray_icon_holder = [None]

    def cleanup_and_exit():
        try:
            if tray_icon_holder[0]:
                tray_icon_holder[0].stop()
        except Exception:
            pass
        try:
            root.destroy()
        except Exception:
            pass
        os._exit(0)

    app = MusicBridgeApp(root, cleanup_and_exit)

    def on_tray_open(icon, item):
        root.after(0, app.show_window)

    def on_toggle_play(icon, item):
        trigger_media_command("toggle")

    def on_prev(icon, item):
        trigger_media_command("prev")

    def on_skip(icon, item):
        trigger_media_command("skip")

    def on_check_updates(icon, item):
        threading.Thread(target=lambda: check_for_updates(auto=False), daemon=True).start()

    def toggle_startup(icon, item):
        new_val = not is_startup_enabled()
        set_startup(new_val)

    menu = pystray.Menu(
        pystray.MenuItem(f"Modular MusicBridge v{VERSION} (Port {PORT})", None, enabled=False),
        pystray.MenuItem("Open MusicBridge App", on_tray_open, default=True),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Play / Pause", on_toggle_play),
        pystray.MenuItem("Next Track / Skip", on_skip),
        pystray.MenuItem("Previous Track", on_prev),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Check for Updates", on_check_updates),
        pystray.MenuItem("Run on Startup", toggle_startup, checked=lambda item: is_startup_enabled()),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Exit", lambda icon, item: cleanup_and_exit())
    )

    tray_icon = pystray.Icon(
        name="ModularMusicBridge",
        icon=create_tray_icon(),
        title=f"Modular MusicBridge v{VERSION} (Active)",
        menu=menu
    )
    tray_icon_holder[0] = tray_icon
    tray_icon.run_detached()

    # If launched with --tray or --background, start minimized
    if "--tray" in sys.argv or "--background" in sys.argv:
        root.withdraw()
    else:
        root.deiconify()

    root.mainloop()

if __name__ == "__main__":
    main()
