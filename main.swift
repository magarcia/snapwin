import Foundation
import ScreenCaptureKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Dispatch
import AppKit

// MARK: - Configuration
struct Config {
    static let outputDirectory = FileManager.default.currentDirectoryPath
}

// MARK: - Main Execution
struct SnapWin {
    @MainActor
    static func run() async -> Int32 {
        initializeAppKit()

        // 1. Parse Arguments
        guard let query = parseArguments() else {
            printUsage()
            return 1
        }

        do {
            // 2. check Permissions (Passive check)
            // Note: Actual prompt triggers on first API call if not granted.

            // 3. Find the Window
            print("🔍 Searching for window matching: \"\(query)\"...")
            let validWindows = try await findWindows(matching: query)

            guard let targetWindow = validWindows.first else {
                print("❌ No window found matching \"\(query)\".")
                print("   (Note: Ensure the app is running and not minimized to the Dock if purely minimized)")
                return 1
            }

            print("✅ Found: [\(targetWindow.owningApplication?.applicationName ?? "Unknown")] - \"\(targetWindow.title ?? "Untitled")\"")

            // 4. Capture
            print("📸 Capturing...")
            if #available(macOS 14.0, *) {
                let image = try await captureWindow(targetWindow)

                // 5. Save
                let filename = "Screenshot-\(targetWindow.owningApplication?.applicationName ?? "App")-\(Int(Date().timeIntervalSince1970)).png"
                let path = saveImage(image, filename: filename)

                print("💾 Saved to: \(path)")
                return 0
            } else {
                print("❌ Error: macOS 14+ is required for SCScreenshotManager.")
                return 1
            }

        } catch {
            print("❌ Error: \(error.localizedDescription)")
            return 1
        }
    }

    // MARK: - Helpers

    static func initializeAppKit() {
        // Ensure CoreGraphics/WindowServer is initialized for CLI context.
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
    }

    static func parseArguments() -> String? {
        let args = CommandLine.arguments
        // usage: snapwin --window "App Name"
        if let index = args.firstIndex(of: "--window"), index + 1 < args.count {
            return args[index + 1]
        }
        return nil
    }

    static func printUsage() {
        print("""
        Usage: snapwin --window <name>

        Examples:
          snapwin --window "WhatsApp"
          snapwin --window "Chrome"
        """)
    }

    static func findWindows(matching query: String) async throws -> [SCWindow] {
        let content = try await SCShareableContent.current

        let queryLower = query.lowercased()

        // Filter windows:
        // 1. Must be on screen (isOnScreen)
        // 2. Match App Name OR Window Title
        let matches = content.windows.filter { window in
            // Basic fuzzy matching: case-insensitive contains
            let appName = window.owningApplication?.applicationName.lowercased() ?? ""
            let title = window.title?.lowercased() ?? ""

            let match = appName.contains(queryLower) || title.contains(queryLower)

            // Filter out menu bars, dock, generic overlays, etc.
            // Usually valid windows have a layer of 0.
            return match && window.isOnScreen && window.windowLayer == 0
        }

        // Sort by relevance (Exact matches first, then partials)
        return matches.sorted {
            let appA = $0.owningApplication?.applicationName.lowercased() ?? ""
            let appB = $1.owningApplication?.applicationName.lowercased() ?? ""

            if appA == queryLower && appB != queryLower { return true }
            return false
        }
    }

    /// Get the actual backing scale factor for the display containing the window
    static func getBackingScaleFactor(for window: SCWindow) -> CGFloat {
        // Find the screen that contains the window (or most of it)
        for screen in NSScreen.screens {
            if screen.frame.intersects(window.frame) {
                return screen.backingScaleFactor
            }
        }
        // Fallback to main screen scale factor, or 2.0 if unavailable
        return NSScreen.main?.backingScaleFactor ?? 2.0
    }

    @available(macOS 14.0, *)
    static func captureWindow(_ window: SCWindow) async throws -> CGImage {
        // Create the filter for just this window
        let filter = SCContentFilter(desktopIndependentWindow: window)

        // Get the actual display scale factor (1.0 for standard, 2.0 for Retina, etc.)
        let scaleFactor = getBackingScaleFactor(for: window)

        // Configure the capture at native resolution
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * scaleFactor)
        config.height = Int(window.frame.height * scaleFactor)
        config.scalesToFit = false  // Capture at native resolution without forced scaling
        config.showsCursor = false
        config.captureResolution = .best

        // Use SCScreenshotManager (macOS 14+) for a "single shot"
        // This is more efficient than opening a stream.
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    static func saveImage(_ image: CGImage, filename: String) -> String {
        let url = URL(fileURLWithPath: Config.outputDirectory).appendingPathComponent(filename)

        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            print("❌ Failed to create image destination.")
            exit(1)
        }

        CGImageDestinationAddImage(dest, image, nil)

        if CGImageDestinationFinalize(dest) {
            return url.path
        } else {
            print("❌ Failed to write image to disk.")
            exit(1)
        }
    }
}

Task {
    let code = await SnapWin.run()
    exit(code)
}
dispatchMain()
