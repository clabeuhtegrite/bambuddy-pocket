// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation
import SwiftUI

/// Tableau de bord des statistiques globales d'impression d'un serveur.
struct ArchiveStatsView: View {
    let model: ArchiveListModel

    @State private var stats: ArchiveStats?
    @State private var failed = false

    var body: some View {
        Group {
            if let stats {
                statsList(stats)
            } else if failed {
                ContentUnavailableView("Statistics unavailable", systemImage: "chart.bar")
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Statistics")
        .toolbarTitleDisplayMode(.inline)
        .task {
            if let result = await model.fetchStats() {
                stats = result
            } else {
                failed = true
            }
        }
    }

    private func statsList(_ stats: ArchiveStats) -> some View {
        List {
            Section("Prints") {
                LabeledContent("Total", value: "\(stats.totalPrints)")
                LabeledContent("Successful", value: "\(stats.successfulPrints)")
                LabeledContent("Failed", value: "\(stats.failedPrints)")
            }
            Section("Usage") {
                LabeledContent("Print time", value: "\(Int(stats.totalPrintTimeHours.rounded())) h")
                LabeledContent("Filament", value: "\(Int(stats.totalFilamentGrams.rounded())) g")
                LabeledContent("Cost", value: stats.totalCost.formatted())
                if let energy = stats.totalEnergyKwh {
                    LabeledContent("Energy", value: "\(energy.formatted()) kWh")
                }
            }
        }
    }
}
