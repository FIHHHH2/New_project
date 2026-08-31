"""
✦ MusicBridge Background System Tray App ✦
Connects Windows Media Session (Spotify, SoundCloud, YouTube, Apple Music)
to the Modular Roblox UI suite at http://127.0.0.1:8888.
Runs silently in the system tray with no terminal window, and includes a "Run on Startup" toggle.
"""

import sys
import os
import json
import time
import asyncio
import threading
import winreg
from http.server import HTTPServer, BaseHTTPRequestHandler
import pystray
from PIL import Image, ImageDraw

APP_NAME = "ModularMusicBridge"
REG_PATH = r"Software\Microsoft\Windows\CurrentVersion\Run"
PORT = 8888

current_media = {
    "title": "No Song Playing",
    "artist": "Waiting for Media...",
    "cover": "rbxassetid://13470984852",
    "lyrics": "Play a track on Spotify / SoundCloud / YouTube",
    "isPlaying": False,
    "position": 0,
    "duration": 0
}

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
    except Exception as e:
        print("Failed to set startup registry key:", e)

# ── Windows Media Session Poller ──────────────────────────────────
async def fetch_windows_media():
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
                current_media["lyrics"] = f"Listening to: {t}"

                if timeline:
                    current_media["position"] = timeline.position.total_seconds() if timeline.position else 0
                    current_media["duration"] = timeline.end_time.total_seconds() if timeline.end_time else 0
        else:
            current_media["title"] = "No Song Playing"
            current_media["artist"] = "Open Spotify / SoundCloud"
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
        time.sleep(0.8)

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
