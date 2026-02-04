# snapwin

`snapwin` is a tiny macOS CLI that captures a screenshot of a specific window by name using Apple's ScreenCaptureKit. It does a single, atomic capture via `SCScreenshotManager` (macOS 14+) and saves a PNG in your current working directory.

**Highlights**
- No focus stealing. The target window stays in the background.
- OS-level privacy. Respects macOS Screen Recording permissions (TCC).
- Offline and local. Writes directly to disk.
- Simple matching. Case-insensitive substring match on app name or window title.

**Requirements**
- macOS 14+ (Sonoma or newer)
- Swift 5.9+ (tested with Swift 6.1.2)
- A logged-in GUI session (ScreenCaptureKit requires WindowServer)

**Build**
```bash
swiftc -O main.swift -o snapwin
```

**Usage**
```bash
./snapwin --window "Codex"
```

**Output**
Screenshots are saved to the current directory as:
`Screenshot-<AppName>-<unix_timestamp>.png`

**Permissions**
The first time you run `snapwin`, macOS will prompt for Screen Recording permission.
- If you're running from Terminal, grant permission to Terminal.
- You can also enable it in: System Settings -> Privacy & Security -> Screen Recording.

**How Matching Works**
The `--window` query is matched case-insensitively against:
- Application name (e.g., \"Chrome\")
- Window title (e.g., \"Docs - Proposal\")
Only on-screen windows with `windowLayer == 0` are considered.

**Troubleshooting**
- `CGS_REQUIRE_INIT` / assertion failed:
  - You're likely running outside a GUI session (for example via SSH to a headless host).
  - ScreenCaptureKit requires a logged-in desktop session with WindowServer.
- \"No window found\":
  - Confirm the app is running and the window is not fully minimized to the Dock.
  - Try a broader substring (e.g., `--window "Chrome"`).

**Security Notes**
- The capture is scoped to a specific window using `SCContentFilter(desktopIndependentWindow:)`.
- No streaming or continuous capture is used - just a single still image.
- No network calls are made.

**License**
MIT License - see LICENSE file for details.
