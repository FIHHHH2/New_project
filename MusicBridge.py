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
from http.server import HTTPServer, BaseHTTPRequestHandler
import pystray
from PIL import Image, ImageDraw

APP_NAME = "ModularMusicBridge"
VERSION = "1.4.3"
REG_PATH = r"Software\Microsoft\Windows\CurrentVersion\Run"
PORT = 8888
VERSION_URL = "https://raw.githubusercontent.com/FIHHHH2/New_project/main/version.json"
SOURCE_URL = "https://raw.githubusercontent.com/FIHHHH2/New_project/main/MusicBridge.py"
EXE_URL = "https://github.com/FIHHHH2/New_project/raw/main/dist/MusicBridge.exe"

current_media = {
    "title": "No Song Playing",
    "artist": "Waiting for Media...",
    "lyrics": "Play a track on Spotify / SoundCloud / YouTube",
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
    "opera.exe", "vivaldi.exe", "vlc.exe", "music.ui.exe",
    "wmplayer.exe", "foobar2000.exe", "itunes.exe", "aimp.exe"
}

smoothed_peak = 0.0
max_recent_peak = 0.02
band_energy = [0.20] * 16
phase = 0.0

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

        return media_peak if media_peak > 0.001 else fallback_peak
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
        pixels = list(small.getdata())

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
def parse_lrc(lrc_text: str):
    lines = []
    for line in lrc_text.splitlines():
        match = re.search(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)', line)
        if match:
            minutes = int(match.group(1))
            seconds = float(match.group(2))
            text = match.group(3).strip()
            total_sec = minutes * 60 + seconds
            if text:
                lines.append((total_sec, text))
    lines.sort(key=lambda x: x[0])
    return lines

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
        for timestamp, text in lines:
            if position >= timestamp:
                active_text = text
            else:
                break
        return active_text if active_text else (lines[0][1] if lines else title)

    elif lyrics_obj["type"] == "plain":
        lines = lyrics_obj["lines"]
        if lines and duration > 0:
            idx = int((position / max(1, duration)) * len(lines))
            idx = max(0, min(len(lines) - 1, idx))
            return lines[idx]

    return f"{title}"

# ── Windows Media Session Poller with Real-Time Timestamp Clock ───
last_song_query = ""

PREFERRED_SOURCE_IDS = ["spotify", "spicetify", "spotifyab", "itunes", "music"]

def pick_best_session(manager):
    """Return Spotify > any actively playing > current > first."""
    try:
        sessions = manager.get_sessions()
        if not sessions:
            return manager.get_current_session()
        all_sessions = list(sessions)
    except Exception:
        return manager.get_current_session()

    # 1. Prefer preferred sources that are actively playing
    for pref in PREFERRED_SOURCE_IDS:
        for s in all_sessions:
            try:
                src = (s.source_app_user_model_id or "").lower()
                pb = s.get_playback_info()
                if pref in src and pb and pb.playback_status.value == 4:
                    return s
            except Exception:
                pass

    # 2. Any preferred source even if paused
    for pref in PREFERRED_SOURCE_IDS:
        for s in all_sessions:
            try:
                src = (s.source_app_user_model_id or "").lower()
                if pref in src:
                    return s
            except Exception:
                pass

    # 3. Any actively playing session
    for s in all_sessions:
        try:
            pb = s.get_playback_info()
            if pb and pb.playback_status.value == 4:
                return s
        except Exception:
            pass

    # 4. Fall back to system current or first
    cur = manager.get_current_session()
    return cur if cur else (all_sessions[0] if all_sessions else None)

async def fetch_windows_media():
    global current_cover_bytes, last_song_query, cover_version_counter
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
                is_playing = (playback.playback_status.value == 4) if playback else True

                current_media["title"] = t
                current_media["artist"] = a
                current_media["isPlaying"] = is_playing

                pos = 0.0
                dur = 0.0
                if timeline:
                    base_pos = timeline.position.total_seconds() if timeline.position else 0.0
                    dur = timeline.end_time.total_seconds() if timeline.end_time else 0.0
                    if is_playing and timeline.last_updated_time:
                        now_utc = datetime.datetime.now(datetime.timezone.utc)
                        elapsed = (now_utc - timeline.last_updated_time).total_seconds()
                        if 0 <= elapsed < 7200:
                            base_pos += elapsed
                    pos = base_pos
                    if dur > 0:
                        pos = min(pos, dur)

                current_media["position"] = round(pos, 2)
                current_media["duration"] = round(dur, 2)

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

                current_lyric = get_current_lyric_line(t, a, pos, dur)
                current_media["lyrics"] = current_lyric
    except Exception:
        pass

async def send_media_control(cmd: str) -> bool:
    try:
        import winrt.windows.foundation.collections
        from winrt.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as SessionManager
        manager = await SessionManager.request_async()
        if not manager:
            return False
        # pick_best_session is sync — do NOT await it
        session = pick_best_session(manager)
        if not session:
            session = manager.get_current_session()
        if session:
            if cmd == "toggle":
                result = await session.try_toggle_play_pause_async()
                print(f"[MediaControl] WinRT toggle -> {result}")
                return result
            elif cmd == "skip":
                result = await session.try_skip_next_async()
                print(f"[MediaControl] WinRT skip -> {result}")
                return result
            elif cmd == "prev":
                result = await session.try_skip_previous_async()
                print(f"[MediaControl] WinRT prev -> {result}")
                return result
    except Exception as e:
        print(f"[MediaControl] WinRT error: {e}")
    return False

# Persistent dedicated event loop for media control commands (avoids asyncio.run conflicts)
_media_ctrl_loop: asyncio.AbstractEventLoop | None = None
_media_ctrl_loop_lock = threading.Lock()
_last_media_cmd_time = 0.0
_media_cmd_lock = threading.Lock()
DEBOUNCE_INTERVAL = 0.40  # 400ms debounce window prevents double execution from hotkeys, repeats, and Luau HTTP calls

def _get_or_create_media_ctrl_loop() -> asyncio.AbstractEventLoop:
    global _media_ctrl_loop
    with _media_ctrl_loop_lock:
        if _media_ctrl_loop is None or _media_ctrl_loop.is_closed():
            loop = asyncio.new_event_loop()
            _media_ctrl_loop = loop
            t = threading.Thread(target=loop.run_forever, daemon=True, name="MediaCtrlLoop")
            t.start()
        return _media_ctrl_loop

def trigger_media_command(cmd: str) -> bool:
    """Executes media command via WinRT session manager targeting Spotify/active session or virtual media key event fallback with atomic 400ms debounce."""
    global _last_media_cmd_time
    with _media_cmd_lock:
        now = time.time()
        if (now - _last_media_cmd_time) < DEBOUNCE_INTERVAL:
            print(f"[MediaControl] Debounced duplicate command '{cmd}' ({now - _last_media_cmd_time:.3f}s < {DEBOUNCE_INTERVAL}s)")
            return True
        _last_media_cmd_time = now

    success = False
    try:
        loop = _get_or_create_media_ctrl_loop()
        future = asyncio.run_coroutine_threadsafe(send_media_control(cmd), loop)
        success = future.result(timeout=4.0)
    except Exception as e:
        print(f"[MediaControl] WinRT dispatch error: {e}")

    if not success:
        print(f"[MediaControl] WinRT failed, falling back to media key event for: {cmd}")
        try:
            import ctypes
            VK_MEDIA_NEXT_TRACK = 0xB0
            VK_MEDIA_PREV_TRACK = 0xB1
            VK_MEDIA_PLAY_PAUSE = 0xB3
            KEYEVENTF_KEYUP = 0x0002
            vk_map = {
                "skip": VK_MEDIA_NEXT_TRACK,
                "prev": VK_MEDIA_PREV_TRACK,
                "toggle": VK_MEDIA_PLAY_PAUSE
            }
            vk = vk_map.get(cmd)
            if vk:
                ctypes.windll.user32.keybd_event(vk, 0, 0, 0)
                time.sleep(0.05)
                ctypes.windll.user32.keybd_event(vk, 0, KEYEVENTF_KEYUP, 0)
                print(f"[MediaControl] Sent virtual media key 0x{vk:02X} for: {cmd}")
                success = True
        except Exception as ke:
            print(f"[MediaControl] Keybd fallback error: {ke}")
    return success

def setup_global_hotkeys():
    """Listens for global Windows shortcuts Win+Q (Previous Song) and Win+E (Skip Song) via low-level hook."""
    try:
        import ctypes
        from ctypes import wintypes

        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32

        WH_KEYBOARD_LL = 13
        WH_MOUSE_LL = 14
        WM_KEYDOWN = 0x0100
        WM_SYSKEYDOWN = 0x0104
        WM_LBUTTONDOWN = 0x0201
        WM_RBUTTONDOWN = 0x0204
        VK_LWIN = 0x5B
        VK_RWIN = 0x5C
        VK_CONTROL = 0x11
        VK_LCONTROL = 0xA2
        VK_RCONTROL = 0xA3
        VK_SHIFT = 0x10
        VK_LSHIFT = 0xA0
        VK_RSHIFT = 0xA1
        VK_MENU = 0x12  # Alt
        VK_LMENU = 0xA4
        VK_RMENU = 0xA5
        VK_LEFT = 0x25
        VK_RIGHT = 0x27
        VK_SPACE = 0x20
        VK_UP = 0x26
        VK_DOWN = 0x28
        VK_Q = 0x51
        VK_E = 0x45

        HOOKPROC = ctypes.WINFUNCTYPE(ctypes.c_long, ctypes.c_int, wintypes.WPARAM, wintypes.LPARAM)

        class KBDLLHOOKSTRUCT(ctypes.Structure):
            _fields_ = [
                ("vkCode", wintypes.DWORD),
                ("scanCode", wintypes.DWORD),
                ("flags", wintypes.DWORD),
                ("time", wintypes.DWORD),
                ("dwExtraInfo", ctypes.c_ulong)
            ]

        def is_win_down():
            return (user32.GetAsyncKeyState(VK_LWIN) & 0x8000 != 0) or (user32.GetAsyncKeyState(VK_RWIN) & 0x8000 != 0)

        def is_ctrl_down():
            return (user32.GetAsyncKeyState(VK_CONTROL) & 0x8000 != 0) or (user32.GetAsyncKeyState(VK_LCONTROL) & 0x8000 != 0) or (user32.GetAsyncKeyState(VK_RCONTROL) & 0x8000 != 0)

        def is_shift_down():
            return (user32.GetAsyncKeyState(VK_SHIFT) & 0x8000 != 0) or (user32.GetAsyncKeyState(VK_LSHIFT) & 0x8000 != 0) or (user32.GetAsyncKeyState(VK_RSHIFT) & 0x8000 != 0)

        def is_alt_down():
            return (user32.GetAsyncKeyState(VK_MENU) & 0x8000 != 0) or (user32.GetAsyncKeyState(VK_LMENU) & 0x8000 != 0) or (user32.GetAsyncKeyState(VK_RMENU) & 0x8000 != 0)

        def low_level_keyboard_proc(nCode, wParam, lParam):
            if nCode >= 0:
                if wParam in (WM_KEYDOWN, WM_SYSKEYDOWN):
                    kbd = KBDLLHOOKSTRUCT.from_address(lParam)
                    vk = kbd.vkCode
                    
                    # 1. Windows Key Combinations
                    if is_win_down():
                        if vk in (VK_RIGHT, VK_E):
                            print("[Hotkey] Win + Right/E -> Skip Song")
                            threading.Thread(target=lambda: trigger_media_command("skip"), daemon=True).start()
                            return 1
                        elif vk in (VK_LEFT, VK_Q):
                            print("[Hotkey] Win + Left/Q -> Previous Song / Go Back")
                            threading.Thread(target=lambda: trigger_media_command("prev"), daemon=True).start()
                            return 1
                        elif vk in (VK_SPACE, VK_DOWN):
                            print("[Hotkey] Win + Space/Down -> Toggle Play/Pause")
                            threading.Thread(target=lambda: trigger_media_command("toggle"), daemon=True).start()
                            return 1

                    # 2. Ctrl + Shift Combinations (Universal Windows shortcut)
                    if is_ctrl_down() and is_shift_down():
                        if vk == VK_RIGHT:
                            print("[Hotkey] Ctrl + Shift + Right -> Skip Song")
                            threading.Thread(target=lambda: trigger_media_command("skip"), daemon=True).start()
                            return 1
                        elif vk == VK_LEFT:
                            print("[Hotkey] Ctrl + Shift + Left -> Previous Song / Go Back")
                            threading.Thread(target=lambda: trigger_media_command("prev"), daemon=True).start()
                            return 1
                        elif vk in (VK_SPACE, VK_UP, VK_DOWN):
                            print("[Hotkey] Ctrl + Shift + Space -> Toggle Play/Pause")
                            threading.Thread(target=lambda: trigger_media_command("toggle"), daemon=True).start()
                            return 1

                    # 3. Ctrl + Alt Combinations
                    if is_ctrl_down() and is_alt_down():
                        if vk == VK_RIGHT:
                            print("[Hotkey] Ctrl + Alt + Right -> Skip Song")
                            threading.Thread(target=lambda: trigger_media_command("skip"), daemon=True).start()
                            return 1
                        elif vk == VK_LEFT:
                            print("[Hotkey] Ctrl + Alt + Left -> Previous Song / Go Back")
                            threading.Thread(target=lambda: trigger_media_command("prev"), daemon=True).start()
                            return 1

            return user32.CallNextHookEx(None, nCode, wParam, lParam)

        def low_level_mouse_proc(nCode, wParam, lParam):
            if nCode >= 0:
                if is_win_down():
                    if wParam == WM_LBUTTONDOWN:
                        print("[Hotkey] Win + Left Click -> Skip Song")
                        threading.Thread(target=lambda: trigger_media_command("skip"), daemon=True).start()
                        return 1
                    elif wParam == WM_RBUTTONDOWN:
                        print("[Hotkey] Win + Right Click -> Go Back a Song")
                        threading.Thread(target=lambda: trigger_media_command("prev"), daemon=True).start()
                        return 1
                elif is_ctrl_down():
                    if wParam == WM_LBUTTONDOWN:
                        print("[Hotkey] Ctrl + Left Click -> Skip Song / Play")
                        threading.Thread(target=lambda: trigger_media_command("skip"), daemon=True).start()
                    elif wParam == WM_RBUTTONDOWN:
                        print("[Hotkey] Ctrl + Right Click -> Go Back a Song")
                        threading.Thread(target=lambda: trigger_media_command("prev"), daemon=True).start()
            return user32.CallNextHookEx(None, nCode, wParam, lParam)

        hook_kbd_cb = HOOKPROC(low_level_keyboard_proc)
        hook_kbd_id = user32.SetWindowsHookExW(WH_KEYBOARD_LL, hook_kbd_cb, kernel32.GetModuleHandleW(None), 0)

        hook_mouse_cb = HOOKPROC(low_level_mouse_proc)
        hook_mouse_id = user32.SetWindowsHookExW(WH_MOUSE_LL, hook_mouse_cb, kernel32.GetModuleHandleW(None), 0)

        print("[Shortcuts] Universal Windows Hotkeys Active:")
        print("  - Win + Left Click / Win + Right Arrow / Ctrl + Shift + Right -> Skip Song")
        print("  - Win + Right Click / Win + Left Arrow / Ctrl + Shift + Left -> Go Back a Song")
        print("  - Ctrl + Shift + Space / Win + Space -> Play / Pause")

        msg = wintypes.MSG()
        while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) != 0:
            user32.TranslateMessage(ctypes.byref(msg))
            user32.DispatchMessageW(ctypes.byref(msg))

        if hook_kbd_id:
            user32.UnhookWindowsHookEx(hook_kbd_id)
        if hook_mouse_id:
            user32.UnhookWindowsHookEx(hook_mouse_id)
    except Exception as e:
        print(f"[Shortcuts] Global hotkey error: {e}")

# ── HTTP Server Request Handler ───────────────────────────────────
class BridgeHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_GET(self):
        path = self.path.lower()

        if path.startswith("/cover.png") or path.startswith("/cover"):
            if current_cover_bytes and len(current_cover_bytes) > 50:
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Content-Length", str(len(current_cover_bytes)))
                self.end_headers()
                self.wfile.write(current_cover_bytes)
                return
            else:
                self.send_response(404)
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(b"No cover available")
                return

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        if path.startswith("/current"):
            self.wfile.write(json.dumps(current_media).encode("utf-8"))
        elif path.startswith("/spectrum"):
            self.wfile.write(json.dumps({
                "peak": current_media["audioPeak"],
                "spectrum": current_media["spectrum"]
            }).encode("utf-8"))
        elif path.startswith("/toggle"):
            trigger_media_command("toggle")
            self.wfile.write(b'{"status":"toggled"}')
        elif path.startswith("/skip"):
            trigger_media_command("skip")
            self.wfile.write(b'{"status":"skipped"}')
        elif path.startswith("/prev"):
            trigger_media_command("prev")
            self.wfile.write(b'{"status":"previous"}')
        elif path.startswith("/update"):
            threading.Thread(target=lambda: check_for_updates(auto=False), daemon=True).start()
            self.wfile.write(b'{"status":"checking_updates"}')
        else:
            self.wfile.write(b'{"status":"ok"}')

def run_http_server():
    server = HTTPServer(("127.0.0.1", PORT), BridgeHandler)
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

            if remote_ver != VERSION:
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

    # Initial update check on startup
    threading.Thread(target=lambda: check_for_updates(auto=True), daemon=True).start()

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

    def toggle_startup(icon, item):
        new_val = not is_startup_enabled()
        set_startup(new_val)

    def on_toggle_play(icon, item):
        trigger_media_command("toggle")

    def on_prev(icon, item):
        trigger_media_command("prev")

    def on_skip(icon, item):
        trigger_media_command("skip")

    def on_check_updates(icon, item):
        threading.Thread(target=lambda: check_for_updates(auto=False), daemon=True).start()

    def on_exit(icon, item):
        icon.stop()
        os._exit(0)

    menu = pystray.Menu(
        pystray.MenuItem(f"Modular MusicBridge v{VERSION} (Port {PORT})", None, enabled=False),
        pystray.MenuItem("Play / Pause Media", on_toggle_play),
        pystray.MenuItem("Previous Track (Win + Q)", on_prev),
        pystray.MenuItem("Next Track / Skip (Win + E)", on_skip),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Check for Updates", on_check_updates),
        pystray.MenuItem("Run on Startup", toggle_startup, checked=lambda item: is_startup_enabled()),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Exit", on_exit)
    )

    icon = pystray.Icon(
        name="ModularMusicBridge",
        icon=create_tray_icon(),
        title=f"Modular MusicBridge v{VERSION} (Win+Q / Win+E Shortcuts Active)",
        menu=menu
    )

    icon.run()

if __name__ == "__main__":
    main()
