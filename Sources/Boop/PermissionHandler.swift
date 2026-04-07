// Sources/Boop/PermissionHandler.swift
import Foundation
import AppKit

/// Wires HTTPServer → PermissionStore → PermissionQueue → OverlayWindowController
class PermissionHandler {
    private let store: PermissionStore
    private let queue: PermissionQueue
    private let overlay: OverlayWindowController

    init(store: PermissionStore, queue: PermissionQueue, overlay: OverlayWindowController) {
        self.store = store
        self.queue = queue
        self.overlay = overlay
    }

    func handle(payload: PermissionPayload, respond: @escaping (HookResponse) -> Void) {
        // Signal activity to keep the Mac awake
        SleepManager.shared.recordActivity()

        let category = ToolCategory.from(toolName: payload.tool_name)

        // Fast path: already allowed (permanent, smart scope, or session)
        if store.shouldAutoApprove(category: category, sessionId: payload.session_id) {
            respond(.allow())
            showAutoApproveToast(for: payload)
            return
        }

        // Slow path: play alert sound then show overlay
        let soundName = store.notificationSound
        let intervals: [Double] = [0, 0.25, 0.5, 0.75]
        for delay in intervals {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSSound(named: .init(soundName))?.play()
            }
        }
        queue.enqueue(sessionId: payload.session_id, payload: payload,
            showOverlay: { [weak self] payload, complete in
                guard let strongSelf = self, let payload = payload else { complete(.allow()); return }
                let why = payload.transcript_path.flatMap { TranscriptReader.read(from: $0) }
                strongSelf.overlay.show(
                    payload: payload,
                    whyText: why,
                    onAllow: { complete(.allow()) },
                    onAllowSession: { [weak self] in
                        self?.store.setSessionAllowed(payload.session_id)
                        complete(.allow())
                    },
                    onAllowPermanently: { [weak self] in
                        try? self?.store.setMode(.permanent)
                        complete(.allow())
                    },
                    onDeny: { complete(.deny()) }
                )
            },
            completion: respond
        )
    }

    private func showAutoApproveToast(for payload: PermissionPayload) {
        guard store.showAutoApproveToast else { return }
        ToastManager.shared.show(payload: payload)
    }
}
