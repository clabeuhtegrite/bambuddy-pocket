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

    /// Délai au-delà duquel, sans aucune image reçue, on bascule sur l'état d'erreur explicite
    /// (plutôt qu'un indicateur tournant à l'infini). Couvre le cas d'un flux/snapshot injoignable
    /// ou bloqué (ex. proxy Cloudflare qui ne renvoie jamais d'octet sur le MJPEG).
    private static let firstFrameTimeout = Duration.seconds(15)

    /// Message d'erreur affiché quand le flux caméra reste injoignable.
    private static let unavailableDescription = LocalizedStringKey(
        "The camera feed couldn’t be reached. Check that the printer is online and the camera is enabled."
    )

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Live camera feed")
            } else if failed {
                ContentUnavailableView {
                    Label("Camera unavailable", systemImage: "video.slash")
                } description: {
                    Text(Self.unavailableDescription)
                }
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
        // Course entre l'acquisition du flux (qui peut ne jamais émettre d'octet si le flux est
        // injoignable/bloqué) et un délai de garde : sans la moindre image au bout du délai, on
        // affiche un état d'erreur explicite plutôt qu'un indicateur tournant à l'infini.
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await feed() }
            group.addTask { await watchdog() }
            // Dès qu'une tâche se termine (timeout déclenché, ou flux fermé), on annule l'autre.
            await group.next()
            group.cancelAll()
        }
    }

    /// Bascule sur l'état d'erreur si aucune image n'est arrivée avant l'échéance.
    private func watchdog() async {
        try? await Task.sleep(for: Self.firstFrameTimeout)
        if !Task.isCancelled, image == nil {
            failed = true
        }
    }

    /// Acquiert le flux MJPEG puis, à défaut, les snapshots. Met à jour `image`/`failed`.
    private func feed() async {
        // Jeton de flux : requis sur un serveur protégé (le flux/snapshot est chargé sans en-tête
        // d'autorisation côté serveur) ; inoffensif si l'auth est désactivée.
        let token = await model.cameraStreamToken()
        if let stream = model.cameraStream(for: printer, token: token) {
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
        await snapshotLoop(token: token)
    }

    private func snapshotLoop(token: String?) async {
        while !Task.isCancelled {
            if let data = await model.cameraSnapshot(for: printer, token: token), let decoded = UIImage(data: data) {
                image = decoded
                failed = false
            } else if image == nil {
                failed = true
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
