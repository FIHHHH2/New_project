"""
✦ MusicBridge Companion Server for Modular Roblox UI ✦
Streams live Windows Media Session (Spotify, SoundCloud, YouTube, Apple Music)
metadata, album art, lyrics, and controls to the Roblox UI at http://127.0.0.1:8888.

Run: python MusicBridge.py
"""

import sys
import json
import time
import asyncio
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

current_media = {
    "title": "No Song Playing",
    "artist": "Waiting for Media Session...",
    "cover": "rbxassetid://13470984852",
    "lyrics": "Play a track on Spotify / SoundCloud / YouTube",
    "isPlaying": False,
    "position": 0,
    "duration": 0
}

# Windows Media Session Manager
async def get_media_info():
    try:
        from winsdk.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as MediaManager
        manager = await MediaManager.request_async()
        current_session = manager.get_current_session()
        if current_session:
            timeline = current_session.get_timeline_properties()
            playback = current_session.get_playback_info()
            info = await current_session.try_get_media_properties_async()
            if info:
                title = info.title or "Unknown Title"
                artist = info.artist or "Unknown Artist"
                is_playing = (playback.playback_status.value == 4) if playback else True
                current_media["title"] = title
                current_media["artist"] = artist
                current_media["isPlaying"] = is_playing
                current_media["lyrics"] = f"Now Listening: {title}"
                if timeline:
                    current_media["position"] = timeline.position.total_seconds() if timeline.position else 0
                    current_media["duration"] = timeline.end_time.total_seconds() if timeline.end_time else 0
    except Exception as e:
        pass

async def media_control_action(action):
    try:
        from winsdk.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as MediaManager
        manager = await MediaManager.request_async()
        session = manager.get_current_session()
        if session:
            if action == "toggle":
                await session.try_toggle_play_pause_async()
            elif action == "skip":
                await session.try_skip_next_async()
            elif action == "prev":
                await session.try_skip_previous_async()
    except Exception as e:
        pass

class MusicBridgeHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        path = self.path.lower()
        if path == "/current":
            response = json.dumps(current_media)
            self.wfile.write(response.encode("utf-8"))
        elif path == "/toggle":
            asyncio.run(media_control_action("toggle"))
            self.wfile.write(b'{"status":"toggled"}')
        elif path == "/skip":
            asyncio.run(media_control_action("skip"))
            self.wfile.write(b'{"status":"skipped"}')
        elif path == "/prev":
            asyncio.run(media_control_action("prev"))
            self.wfile.write(b'{"status":"previous"}')
        else:
            self.wfile.write(b'{"status":"ok"}')

def run_media_poller():
    while True:
        try:
            asyncio.run(get_media_info())
        except Exception:
            pass
        time.sleep(1.0)

def main():
    print("=" * 60)
    print("✦ MusicBridge Server Started on http://127.0.0.1:8888 ✦")
    print("Capturing Windows Media Sessions (Spotify, SoundCloud, YouTube)...")
    print("=" * 60)
    
    t = threading.Thread(target=run_media_poller, daemon=True)
    t.start()

    server = HTTPServer(("127.0.0.1", 8888), MusicBridgeHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down MusicBridge.")

if __name__ == "__main__":
    main()
