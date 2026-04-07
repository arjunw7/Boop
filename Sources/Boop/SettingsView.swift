// Sources/Boop/SettingsView.swift
import SwiftUI
import ServiceManagement
import AppKit

// MARK: - Available notification sounds
private let kNotificationSounds = [
    "Basso", "Blow", "Bottle", "Frog", "Funk",
    "Glass", "Hero", "Morse", "Ping", "Pop",
    "Purr", "Sosumi", "Submarine", "Tink",
]

// MARK: - SettingsTab

private enum SettingsTab: String, CaseIterable {
    case consentMode = "Consent Mode"
    case preferences = "Preferences"
}

// MARK: - Brand colour
private extension Color {
    static let boopGreen = Color(red: 0.06, green: 0.73, blue: 0.51)
}

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var store: PermissionStoreObservable

    @State private var selectedTab: SettingsTab = .consentMode
    @State private var isWinking: Bool = false
    @State private var smileAmount: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            boopHeader

            // Segmented control
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                contentSection
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 480, height: 484)
        .ignoresSafeArea()
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Content section

    @ViewBuilder
    private var contentSection: some View {
        switch selectedTab {
        case .consentMode:
            permissionModeSection
        case .preferences:
            preferencesSection
        }
    }

    // MARK: - Permission mode

    private var permissionModeSection: some View {
        VStack(spacing: 8) {
            ForEach(PermissionMode.allCases, id: \.self) { mode in
                ModeRow(
                    mode: mode,
                    isSelected: store.mode == mode,
                    action: { store.mode = mode }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Show toast for auto-approved tools", systemImage: "checkmark.bubble")
                    .font(.system(size: 13))
                Spacer()
                Toggle("", isOn: $store.showAutoApproveToast)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            HStack {
                Label("Alert sound", systemImage: "speaker.wave.2")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $store.notificationSound) {
                    ForEach(kNotificationSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                .onChange(of: store.notificationSound) { sound in
                    NSSound(named: .init(sound))?.play()
                }
            }

            Divider()

            HStack {
                Label("Prevent sleep while Claude is active", systemImage: "moon.zzz")
                    .font(.system(size: 13))
                Spacer()
                Toggle("", isOn: $store.preventSleep)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            HStack {
                Label("Launch Boop at login", systemImage: "arrow.clockwise.circle")
                    .font(.system(size: 13))
                Spacer()
                Toggle("", isOn: $store.launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Animated header

    private var boopHeader: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.12),
                    Color(red: 0.10, green: 0.10, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(alignment: .center, spacing: 14) {
                // Smiley face — eyes on top, mouth below, centered
                VStack(spacing: 7) {
                    // Eyes row
                    HStack(spacing: 5) {
                        // Left eye — steady circle
                        Circle()
                            .fill(Color.boopGreen)
                            .frame(width: 10, height: 10)

                        // Right eye — circle or chevron
                        ZStack {
                            Circle()
                                .fill(Color.boopGreen)
                                .frame(width: 10, height: 10)
                                .opacity(isWinking ? 0 : 1)

                            // Chevron pointing left <
                            Path { path in
                                path.move(to: CGPoint(x: 9, y: 0))
                                path.addLine(to: CGPoint(x: 1.5, y: 5))
                                path.addLine(to: CGPoint(x: 9, y: 10))
                            }
                            .stroke(Color.boopGreen, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .frame(width: 10, height: 10)
                            .opacity(isWinking ? 1 : 0)
                        }
                        .frame(width: 10, height: 10)
                    }

                    // Mouth — centered below eyes
                    BoopMouth(smileAmount: smileAmount)
                        .stroke(Color.boopGreen, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 24, height: 7)
                }

                Text("boop")
                    .font(.custom("Comfortaa-Medium", size: 22))
                    .foregroundColor(Color.boopGreen)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
        }
        .frame(height: 95)
        .onAppear {
            startWinkCycle()
        }
    }

    private func startWinkCycle() {
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isWinking = true
                    smileAmount = 1.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isWinking = false
                    smileAmount = 0.0
                }
            }
        }
    }
}

// MARK: - BoopMouth

private struct BoopMouth: Shape {
    var smileAmount: CGFloat  // 0 = straight, 1 = full smile

    var animatableData: CGFloat {
        get { smileAmount }
        set { smileAmount = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let controlY = rect.minY + (smileAmount * rect.height * 1.4)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: controlY)
        )
        return path
    }
}

// MARK: - ModeRow

private struct ModeRow: View {
    let mode: PermissionMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.boopGreen : Color.secondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(Color.boopGreen)
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .primary.opacity(0.8))
                    Text(mode.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.boopGreen.opacity(0.07) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                isSelected ? Color.boopGreen.opacity(0.25) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PermissionStoreObservable

class PermissionStoreObservable: ObservableObject {
    let underlyingStore: PermissionStore
    @Published var mode: PermissionMode { didSet { try? underlyingStore.setMode(mode) } }
    @Published var showAutoApproveToast: Bool = true {
        didSet { underlyingStore.showAutoApproveToast = showAutoApproveToast }
    }
    @Published var preventSleep: Bool {
        didSet {
            try? underlyingStore.setPreventSleep(preventSleep)
            SleepManager.shared.autoPreventSleep = preventSleep
            if !preventSleep && !SleepManager.shared.manualOverride {
                SleepManager.shared.releaseAll()
            }
        }
    }
    @Published var launchAtLogin: Bool = false {
        didSet {
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }
    @Published var notificationSound: String {
        didSet { try? underlyingStore.setNotificationSound(notificationSound) }
    }

    init(store: PermissionStore) {
        self.underlyingStore = store
        self.mode = store.mode
        self.preventSleep = store.preventSleep
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.notificationSound = store.notificationSound
        // Sync initial state to SleepManager
        SleepManager.shared.autoPreventSleep = store.preventSleep
    }
}
