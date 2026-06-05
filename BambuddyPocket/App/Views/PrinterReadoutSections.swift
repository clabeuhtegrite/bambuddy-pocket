// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Sections en lecture seule : températures (adaptatives au modèle) et ventilateurs réels.
///
/// S'adapte aux **capacités** de l'imprimante : la seconde buse et l'extrudeur actif ne sont
/// affichés que sur un modèle double extrudeur **qui expose réellement** la donnée ; la chambre
/// n'apparaît que si le statut rapporte une température de chambre ; chaque ventilateur n'apparaît
/// que si sa valeur est présente.
struct PrinterReadoutSections: View {
    let status: PrinterStatus?
    let capabilities: PrinterCapabilities

    /// L'UI doit-elle afficher la seconde buse (modèle dual **et** donnée présente dans le statut) ?
    private var showsSecondNozzle: Bool {
        status?.showsSecondNozzle(capabilities: capabilities) ?? false
    }

    var body: some View {
        temperatureSection
        fansSection
    }

    @ViewBuilder
    private var temperatureSection: some View {
        if let temps = status?.temperatures {
            Section("Temperatures") {
                if showsSecondNozzle {
                    temperatureRow("Nozzle 1", temps.nozzle, temps.nozzleTarget)
                    temperatureRow("Nozzle 2", temps.nozzle2, temps.nozzle2Target)
                    if let active = status?.activeExtruder {
                        LabeledContent("Active extruder", value: PrinterPresentation.activeExtruderLabel(active))
                    }
                } else {
                    temperatureRow("Nozzle", temps.nozzle, temps.nozzleTarget)
                }
                temperatureRow("Bed", temps.bed, temps.bedTarget)
                if temps.chamber != nil {
                    temperatureRow("Chamber", temps.chamber, temps.chamberTarget)
                }
            }
        }
    }

    private func temperatureRow(_ label: LocalizedStringKey, _ current: Double?, _ target: Double?) -> some View {
        LabeledContent(label, value: PrinterPresentation.temperaturePair(current, target))
    }

    @ViewBuilder
    private var fansSection: some View {
        if let status, status.coolingFanSpeed != nil || status.bigFan1Speed != nil {
            Section("Fans") {
                if let speed = status.coolingFanSpeed {
                    LabeledContent("Part cooling", value: "\(speed)%")
                }
                if let speed = status.bigFan1Speed {
                    LabeledContent("Auxiliary", value: "\(speed)%")
                }
                if let speed = status.bigFan2Speed {
                    LabeledContent("Chamber fan", value: "\(speed)%")
                }
                if let speed = status.heatbreakFanSpeed {
                    LabeledContent("Heatbreak", value: "\(speed)%")
                }
            }
        }
    }
}
