"""
✦ MusicBridge Background System Tray App ✦
Connects Windows Media Session (Spotify, SoundCloud, YouTube, Apple Music)
to the Modular Roblox UI suite at http://127.0.0.1:8888.

Features:
- Live iTunes & Deezer High-Res Album Cover Art fetcher for Spotify/SoundCloud/Apple Music/YouTube
- LRCLIB Synchronized Lyrics fetcher (real-time timestamp matching)
- Windowless system tray app with "Run on Startup" toggle
"""

import sys
import os
import json
import time
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
    "cover": "rbxassetid://7072718362",
    "lyrics": "Play a track on Spotify / SoundCloud / YouTube",
    "isPlaying": False,
    "position": 0,
    "duration": 0
}

# Cache for cover art and parsed lyrics
cover_cache = {}
lyrics_cache = {}

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

# ── Online Album Cover Art Fetcher (iTunes / Deezer) ───────────────
def fetch_online_cover_art(title: str, artist: str) -> str:
    clean_title = re.sub(r'\(.*?\)|\[.*?\]|ft\..*|feat\..*', '', title).strip()
    cache_key = f"{clean_title}_{artist}".lower()
    if cache_key in cover_cache:
        return cover_cache[cache_key]

    headers = {"User-Agent": "Mozilla/5.0"}
    
    # 1. Try iTunes Search API
    try:
        q = urllib.parse.quote(f"{clean_title} {artist}".strip())
        url = f"https://itunes.apple.com/search?term={q}&entity=song&limit=1"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data.get("resultCount", 0) > 0:
                art = data["results"][0].get("artworkUrl100", "")
                if art:
                    high_res = art.replace("100x100bb", "600x600bb")
                    cover_cache[cache_key] = high_res
                    return high_res
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
                art = album.get("cover_xl") or album.get("cover_big") or album.get("cover_medium")
                if art:
                    cover_cache[cache_key] = art
                    return art
    except Exception:
        pass

    cover_cache[cache_key] = "rbxassetid://7072718362"
    return "rbxassetid://7072718362"

# ── Synchronized Lyrics Fetcher (LRCLIB) ───────────────────────────
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
    clean_title = re.sub(r'\(.*?\)|\[.*?\]|ft\..*|feat\..*', '', title).strip()
    cache_key = f"{clean_title}_{artist}".lower()
    if cache_key in lyrics_cache:
        return lyrics_cache[cache_key]

    headers = {"User-Agent": "Mozilla/5.0"}
    try:
        q_title = urllib.parse.quote(clean_title)
        q_artist = urllib.parse.quote(artist)
        url = f"https://lrclib.net/api/get?artist_name={q_artist}&track_name={q_title}"
        if duration > 0:
            url += f"&duration={int(duration)}"

        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            synced = data.get("syncedLyrics")
            if synced:
                parsed = parse_lrc(synced)
                lyrics_cache[cache_key] = {"type": "synced", "lines": parsed}
                return lyrics_cache[cache_key]

            plain = data.get("plainLyrics")
            if plain:
                plain_lines = [l.strip() for l in plain.splitlines() if l.strip()]
                lyrics_cache[cache_key] = {"type": "plain", "lines": plain_lines}
                return lyrics_cache[cache_key]
    except Exception:
        pass

    # Search endpoint fallback
    try:
        q = urllib.parse.quote(f"{clean_title} {artist}".strip())
        url = f"https://lrclib.net/api/search?q={q}"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            results = json.loads(resp.read().decode("utf-8"))
            if results and isinstance(results, list) and len(results) > 0:
                first = results[0]
                if first.get("syncedLyrics"):
                    parsed = parse_lrc(first["syncedLyrics"])
                    lyrics_cache[cache_key] = {"type": "synced", "lines": parsed}
                    return lyrics_cache[cache_key]
                elif first.get("plainLyrics"):
                    plain_lines = [l.strip() for l in first["plainLyrics"].splitlines() if l.strip()]
                    lyrics_cache[cache_key] = {"type": "plain", "lines": plain_lines}
                    return lyrics_cache[cache_key]
    except Exception:
        pass

    lyrics_cache[cache_key] = None
    return None

def get_current_lyric_line(title: str, artist: str, position: float, duration: float) -> str:
    lyrics_obj = fetch_synced_lyrics(title, artist, duration)
    if not lyrics_obj:
        return f"Listening to: {title}"

    if lyrics_obj["type"] == "synced":
        lines = lyrics_obj["lines"]
        active_text = ""
        for timestamp, text in lines:
            if position >= timestamp:
                active_text = text
            else:
                break
        return active_text if active_text else lines[0][1] if lines else f"Listening to: {title}"

    elif lyrics_obj["type"] == "plain":
        lines = lyrics_obj["lines"]
        if lines and duration > 0:
            idx = int((position / max(1, duration)) * len(lines))
            idx = max(0, min(len(lines) - 1, idx))
            return lines[idx]

    return f"Listening to: {title}"

# ── Windows Media Session Poller ──────────────────────────────────
last_fetched_title = ""

async def fetch_windows_media():
    global last_fetched_title
    try:
        from winrt.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as SessionManager
        manager = await SessionManager.request_async()
        if not manager:
            return

        session = manager.get_current_session()
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

                pos = timeline.position.total_seconds() if timeline and timeline.position else 0
                dur = timeline.end_time.total_seconds() if timeline and timeline.end_time else 0
                current_media["position"] = pos
                current_media["duration"] = dur

                # Fetch Cover Art asynchronously
                cover_url = fetch_online_cover_art(t, a)
                current_media["cover"] = cover_url

                # Get Synchronized Real-Time Lyrics
                current_lyric = get_current_lyric_line(t, a, pos, dur)
                current_media["lyrics"] = current_lyric
        else:
            current_media["title"] = "No Song Playing"
            current_media["artist"] = "Idle"
            current_media["cover"] = "rbxassetid://7072718362"
            current_media["lyrics"] = "Waiting for audio session..."
            current_media["isPlaying"] = False
    except Exception:
        pass

async def send_media_control(cmd: str):
    try:
        from winrt.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as SessionManager
        manager = await SessionManager.request_async()
        if not manager:
            return
        session = manager.get_current_session()
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
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        path = self.path.lower()
        if path == "/current":
            self.wfile.write(json.dumps(current_media).encode("utf-8"))
        elif path == "/toggle":
            asyncio.run(send_media_control("toggle"))
            self.wfile.write(b'{"status":"toggled"}')
        elif path == "/skip":
            asyncio.run(send_media_control("skip"))
            self.wfile.write(b'{"status":"skipped"}')
        elif path == "/prev":
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
        time.sleep(0.6)

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
