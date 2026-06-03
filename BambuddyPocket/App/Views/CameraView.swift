// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import SwiftUI
import UIKit

/// Vue caméra : affiche le flux par **snapshots** rafraîchis (~1 s). Le vrai flux MJPEG
/// multipart pourra remplacer cette approche ultérieurement.
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
        .task { await refreshLoop() }
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            if let data = await model.cameraSnapshot(for: printer), let frame = UIImage(data: data) {
                image = frame
                failed = false
            } else if image == nil {
                failed = true
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
