// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import Foundation
import SwiftUI
import WebKit

/// Données d'un modèle à visualiser : contenu brut + extension (`stl` / `3mf` / `gcode`).
struct ModelPayload: Hashable {
    let data: Data
    let ext: String
}

/// Viewer 3D embarqué : `WKWebView` + Three.js **bundlé** (hors-ligne, sans dépendance réseau).
/// Le modèle est injecté via un `WKUserScript` à `documentStart`, la page le rend : maillage
/// (STL/3MF) ou **parcours d'outil** (G-code, déplacements d'extrusion en lignes).
struct Model3DView: UIViewRepresentable {
    let payload: ModelPayload

    func makeUIView(context _: Context) -> WKWebView {
        let controller = WKUserContentController()
        let base64 = payload.data.base64EncodedString()
        let source = "window.__MODEL_B64=\"\(base64)\";window.__MODEL_EXT=\"\(payload.ext)\";"
        controller.addUserScript(
            WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        let htmlURL = Bundle.main.url(forResource: "viewer", withExtension: "html")
            ?? Bundle.main.url(forResource: "viewer", withExtension: "html", subdirectory: "Viewer")
        if let htmlURL {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}
}

/// Écran qui télécharge le fichier d'une archive puis affiche le viewer 3D.
struct Model3DScreen: View {
    let archive: Archive
    let model: ArchiveListModel

    @State private var payload: ModelPayload?
    @State private var failed = false

    var body: some View {
        Group {
            if let payload {
                Model3DView(payload: payload)
                    .ignoresSafeArea(edges: .bottom)
                    // Le canvas WebGL est invisible à VoiceOver : on expose un élément unique
                    // décrivant l'aperçu interactif.
                    .accessibilityElement()
                    .accessibilityLabel(Text("3D preview of \(archive.displayName)"))
                    .accessibilityHint(Text("Interactive 3D viewer. Rotate, pan and zoom by touch."))
            } else if failed {
                ContentUnavailableView("3D preview unavailable", systemImage: "cube.transparent")
            } else {
                ProgressView()
                    .tint(DSColor.accent)
                    .accessibilityLabel(Text("Loading 3D preview"))
            }
        }
        .navigationTitle("3D model")
        .toolbarTitleDisplayMode(.inline)
        .task {
            if let result = await model.downloadModel(archive) {
                payload = result
            } else {
                failed = true
            }
        }
    }
}
