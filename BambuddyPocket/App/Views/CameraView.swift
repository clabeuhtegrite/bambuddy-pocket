// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import SwiftUI
import UIKit

/// Vue caméra : tente le **flux MJPEG** temps réel, avec repli sur des **snapshots** rafraîchis.
struct CameraView: View {
    let printer: Printer
    let model: PrinterListModel

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if failed {
                ContentUnavailableView("Camera unavailable", systemImage: "video.slash")
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Camera")
        .toolbarTitleDisplayMode(.inline)
        .task { await run() }
    }

    private func run() async {
        if let stream = model.cameraStream(for: printer) {
            do {
                for try await frame in stream.frames() {
                    try Task.checkCancellation()
                    if let decoded = UIImage(data: frame) {
                        image = decoded
                        failed = false
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                // Flux indisponible → repli sur les snapshots ci-dessous.
            }
        }
        await snapshotLoop()
    }

    private func snapshotLoop() async {
        while !Task.isCancelled {
            if let data = await model.cameraSnapshot(for: printer), let decoded = UIImage(data: data) {
                image = decoded
                failed = false
            } else if image == nil {
                failed = true
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
