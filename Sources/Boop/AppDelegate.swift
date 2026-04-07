// Sources/Boop/AppDelegate.swift
import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var httpServer: HTTPServer!
    private var permissionStore: PermissionStore!
    private var permissionQueue: PermissionQueue!
    private var overlayController: OverlayWindowController!
    private var permissionHandler: PermissionHandler!
    private var settingsController: SettingsWindowController!
    private var storeObservable: PermissionStoreObservable!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerCustomFonts()

        permissionStore = PermissionStore()
        permissionQueue = PermissionQueue()
        overlayController = OverlayWindowController()
        permissionHandler = PermissionHandler(
            store: permissionStore,
            queue: permissionQueue,
            overlay: overlayController
        )
        storeObservable = PermissionStoreObservable(store: permissionStore)
        settingsController = SettingsWindowController()

        setupMenuBar()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        startHTTPServer()
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Boop")
        }

        let menu = NSMenu()
        let activeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let activeString = NSMutableAttributedString()
        activeString.append(NSAttributedString(string: "●  ", attributes: [
            .foregroundColor: NSColor(red: 0.055, green: 0.733, blue: 0.514, alpha: 1.0),
            .font: NSFont.systemFont(ofSize: 12)
        ]))
        activeString.append(NSAttributedString(string: "Active", attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 13)
        ]))
        activeItem.attributedTitle = activeString
        menu.addItem(activeItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Boop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        settingsController.showSettings(store: storeObservable)
    }

    func applicationWillTerminate(_ notification: Notification) {
        SleepManager.shared.releaseAll()
    }

    // MARK: - HTTP server

    private func startHTTPServer() {
        httpServer = HTTPServer()
        httpServer.onPermissionRequest = { [weak self] payload, respond in
            self?.permissionHandler.handle(payload: payload, respond: respond)
        }
        do {
            let actualPort = try httpServer.startWithFallback(basePort: 29001, maxAttempts: 10)
            print("[Boop] HTTP server started on port \(actualPort)")
            patchClaudeSettings(port: actualPort)
        } catch {
            let logDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".boop")
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
            let msg = "[\(Date())] Failed to start HTTP server: \(error)\n"
            try? msg.data(using: .utf8)?.write(to: logDir.appendingPathComponent("errors.log"))

            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: "hand.raised.slash", accessibilityDescription: "Boop Error")
            }
        }
    }

    private func registerCustomFonts() {
        if let fontURL = Bundle.main.url(forResource: "Comfortaa-Medium", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }

    /// Updates the Claude Code hook URL in ~/.claude/settings.json to point at the actual port.
    private func patchClaudeSettings(port: UInt16) {
        let settingsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")

        guard let data = try? Data(contentsOf: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let hookURL = "http://localhost:\(port)/permission"

        let newHook: [[String: Any]] = [
            [
                "matcher": "",
                "hooks": [
                    ["type": "http", "url": hookURL]
                ]
            ]
        ]

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        hooks["PermissionRequest"] = newHook
        settings["hooks"] = hooks

        guard let updatedData = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        try? updatedData.write(to: settingsPath, options: .atomic)
        print("[Boop] Updated hook URL to \(hookURL)")
    }
}
