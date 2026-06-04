// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Profils d'avance de pression (K) stockés sur l'imprimante — **consultation seule**.
///
/// L'app n'applique ni ne supprime aucun profil : elle se contente de lire la calibration que
/// l'imprimante a mémorisée (un appel de calibration sur l'imprimante peut être long, d'où le
/// chargement explicite et le repli en cas d'absence de réponse).
struct KProfilesView: View {
    let printer: Printer
    let model: PrinterListModel

    @State private var response: KProfilesResponse?
    @State private var hasLoaded = false
    @State private var isLoading = false

    var body: some View {
        List {
            if let response, !response.profiles.isEmpty {
                Section {
                    LabeledContent("Nozzle diameter", value: "\(response.nozzleDiameter) mm")
                        .listRowBackground(DSColor.card)
                }
                ForEach(response.profiles) { profile in
                    Section {
                        KProfileRow(profile: profile)
                            .listRowBackground(DSColor.card)
                    }
                }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Pressure advance")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task {
            if !hasLoaded {
                await load()
            }
        }
    }

    private func load() async {
        isLoading = true
        response = await model.kProfiles(for: printer)
        isLoading = false
        hasLoaded = true
    }

    @ViewBuilder
    private var placeholder: some View {
        if isLoading, response == nil {
            ProgressView().tint(DSColor.accent)
        } else if response?.profiles.isEmpty ?? true {
            ContentUnavailableView(
                "No K-profiles",
                systemImage: "scope",
                description: Text("The printer reported no pressure-advance calibration profiles.")
            )
        }
    }
}

/// Une ligne de profil K : nom, valeur K, buse/filament et emplacement AMS éventuel.
private struct KProfileRow: View {
    let profile: KProfile

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text(profile.name)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Text(profile.kValue)
                    .font(.callout.monospaced())
                    .foregroundStyle(DSColor.accent)
            }
            LabeledContent("Nozzle", value: "\(profile.nozzleDiameter) mm")
            LabeledContent("Filament", value: profile.filamentID)
            if let tray = profile.trayID, tray >= 0 {
                LabeledContent("AMS slot", value: "\(profile.amsID ?? 0) · \(tray)")
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
