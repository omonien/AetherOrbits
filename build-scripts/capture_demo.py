"""Capture an Aether Orbits window to PNG frames via DXGI (dxcam).

Usage (from repo root, app already running or started separately):
  python build-scripts/capture_demo.py <pid> <outDir> <fps> <seconds>

Requires: pip install dxcam opencv-python-headless pillow
OpenGL/Skia content needs DXGI Desktop Duplication — plain GDI grab is black.
"""
import time, sys, os
import dxcam
from PIL import Image
import ctypes
from ctypes import wintypes

user32 = ctypes.windll.user32

class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

EnumWindows = user32.EnumWindows
EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
GetWindowThreadProcessId = user32.GetWindowThreadProcessId
IsWindowVisible = user32.IsWindowVisible
GetWindowTextW = user32.GetWindowTextW
GetWindowTextLengthW = user32.GetWindowTextLengthW
GetWindowRect = user32.GetWindowRect
SetForegroundWindow = user32.SetForegroundWindow
ShowWindow = user32.ShowWindow
SetWindowPos = user32.SetWindowPos

def find_hwnd(pid):
    result = []
    def cb(hwnd, lParam):
        p = wintypes.DWORD()
        GetWindowThreadProcessId(hwnd, ctypes.byref(p))
        if p.value == pid and IsWindowVisible(hwnd):
            length = GetWindowTextLengthW(hwnd)
            if length > 0:
                buf = ctypes.create_unicode_buffer(length + 1)
                GetWindowTextW(hwnd, buf, length + 1)
                result.append((hwnd, buf.value))
        return True
    EnumWindows(EnumWindowsProc(cb), 0)
    return result[0] if result else (None, None)

def main():
    pid = int(sys.argv[1])
    out_dir = sys.argv[2]
    fps = int(sys.argv[3])
    seconds = float(sys.argv[4])
    os.makedirs(out_dir, exist_ok=True)

    hwnd = None
    title = None
    for _ in range(50):
        hwnd, title = find_hwnd(pid)
        if hwnd:
            break
        time.sleep(0.2)
    if not hwnd:
        print("window not found", file=sys.stderr)
        return 1
    print(f"hwnd={hwnd} title={title}")
    ShowWindow(hwnd, 9)
    SetWindowPos(hwnd, 0, 80, 60, 1280, 720, 0x0040)
    SetForegroundWindow(hwnd)
    time.sleep(2.5)

    rect = RECT()
    GetWindowRect(hwnd, ctypes.byref(rect))
    region = (rect.left, rect.top, rect.right, rect.bottom)
    print(f"region={region}")

    camera = dxcam.create(output_color="RGB")
    camera.start(region=region, target_fps=fps, video_mode=True)
    time.sleep(0.3)

    n = int(fps * seconds)
    interval = 1.0 / fps
    t0 = time.perf_counter()
    saved = 0
    for i in range(n):
        frame = camera.get_latest_frame()
        if frame is not None:
            Image.fromarray(frame).save(os.path.join(out_dir, f"f{i:04d}.png"))
            saved += 1
        # pace
        target = t0 + (i + 1) * interval
        delay = target - time.perf_counter()
        if delay > 0:
            time.sleep(delay)
    camera.stop()
    print(f"frames={saved}")
    return 0 if saved > 0 else 1

if __name__ == "__main__":
    raise SystemExit(main())
