// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
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
    @State private var plateCheck: PlateCheck?
    @State private var showsPlateResult = false
    @State private var isChecking = false

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if failed {
                ContentUnavailableView("Camera unavailable", systemImage: "video.slash")
            } else {
                ProgressView()
                    .tint(DSColor.accent)
            }
        }
        .navigationTitle("Camera")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await runPlateCheck() }
                } label: {
                    Label("Check plate", systemImage: "checkmark.rectangle.stack")
                }
                .disabled(isChecking)
            }
        }
        .alert(
            plateCheck?.isEmpty == true ? "Plate looks empty" : "Plate not empty",
            isPresented: $showsPlateResult,
            presenting: plateCheck
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { result in
            Text(plateMessage(for: result))
        }
        .task { await run() }
    }

    private func runPlateCheck() async {
        isChecking = true
        if let result = await model.checkPlate(for: printer) {
            plateCheck = result
            showsPlateResult = true
        }
        isChecking = false
    }

    private func plateMessage(for result: PlateCheck) -> String {
        var parts: [String] = []
        if let message = result.message, !message.isEmpty {
            parts.append(message)
        }
        let confidence = String(
            localized: "Confidence: \(result.confidencePercent)%",
            comment: "Plate detection confidence level"
        )
        parts.append(confidence)
        if result.needsCalibration == true {
            parts.append(String(localized: "Calibration required.", comment: "Plate detection hint"))
        }
        if result.lightWarning == true {
            parts.append(String(localized: "Turn on the chamber light for reliable detection.", comment: "Plate hint"))
        }
        return parts.joined(separator: "\n")
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
