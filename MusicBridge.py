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
REG_PATH = r"Software\Microsoft\Windows\CurrentVersion\Run"
PORT = 8888

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

    # Balanced Musical Automatic Gain Control
    if peak > max_recent_peak:
        max_recent_peak = max(0.005, peak)
    else:
        max_recent_peak = max(0.005, max_recent_peak * 0.992)

    ratio = min(1.0, peak / max(0.005, max_recent_peak))
    boosted_peak = math.pow(ratio, 0.75) * 1.0 if ratio > 0 else 0.0
    boosted_peak = max(0.0, min(1.0, boosted_peak))

    # Silky smooth attack and decay
    if boosted_peak > smoothed_peak:
        smoothed_peak = smoothed_peak * 0.35 + boosted_peak * 0.65
    else:
        smoothed_peak = smoothed_peak * 0.88 + boosted_peak * 0.12

    current_media["audioPeak"] = round(smoothed_peak, 3)

    phase += 0.12
    new_spectrum = []
    for i in range(16):
        bass_mult = 1.15 if i < 5 else (1.05 if i < 10 else 0.90)
        osc = math.sin(phase * (0.85 + i * 0.15) + i * 0.45) * 0.20 + 0.80
        val = max(0.05, min(1.0, (smoothed_peak * bass_mult * osc)))
        band_energy[i] = band_energy[i] * 0.75 + val * 0.25
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
                data = json.loads(resp.read().decode("utf-8"))
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
            data = json.loads(resp.read().decode("utf-8"))
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
                    data = json.loads(resp.read().decode("utf-8"))
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
                results = json.loads(resp.read().decode("utf-8"))
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
                data = json.loads(resp.read().decode("utf-8"))
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

async def fetch_windows_media():
    global current_cover_bytes, last_song_query, cover_version_counter
    try:
        from winrt.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as SessionManager
        from winrt.windows.storage.streams import DataReader
        manager = await SessionManager.request_async()
        if not manager:
            return

        session = manager.get_current_session()
        if not session:
            sessions = manager.get_sessions()
            if sessions and len(sessions) > 0:
                session = sessions[0]

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

async def send_media_control(cmd: str):
    try:
        from winrt.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as SessionManager
        manager = await SessionManager.request_async()
        if not manager:
            return
        session = manager.get_current_session()
        if not session:
            sessions = manager.get_sessions()
            if sessions and len(sessions) > 0:
                session = sessions[0]
        if session:
            if cmd == "toggle":
                await session.try_toggle_play_pause_async()
            elif cmd == "skip":
                await session.try_skip_next_async()
            elif cmd == "prev":
                await session.try_skip_previous_async()
    except Exception:
        pass

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
            asyncio.run(send_media_control("toggle"))
            self.wfile.write(b'{"status":"toggled"}')
        elif path.startswith("/skip"):
            asyncio.run(send_media_control("skip"))
            self.wfile.write(b'{"status":"skipped"}')
        elif path.startswith("/prev"):
            asyncio.run(send_media_control("prev"))
            self.wfile.write(b'{"status":"previous"}')
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
        time.sleep(0.033)

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
    t1 = threading.Thread(target=run_http_server, daemon=True)
    t1.start()

    t2 = threading.Thread(target=run_media_loop, daemon=True)
    t2.start()

    t3 = threading.Thread(target=run_audio_loop, daemon=True)
    t3.start()

    def toggle_startup(icon, item):
        new_val = not is_startup_enabled()
        set_startup(new_val)

    def on_toggle_play(icon, item):
        asyncio.run(send_media_control("toggle"))

    def on_skip(icon, item):
        asyncio.run(send_media_control("skip"))

    def on_exit(icon, item):
        icon.stop()
        os._exit(0)

    menu = pystray.Menu(
        pystray.MenuItem("Modular MusicBridge (Port 8888)", None, enabled=False),
        pystray.MenuItem("Play / Pause Media", on_toggle_play),
        pystray.MenuItem("Skip Track", on_skip),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Run on Startup", toggle_startup, checked=lambda item: is_startup_enabled()),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Exit", on_exit)
    )

    icon = pystray.Icon(
        name="ModularMusicBridge",
        icon=create_tray_icon(),
        title="Modular MusicBridge (Running)",
        menu=menu
    )

    icon.run()

if __name__ == "__main__":
    main()
