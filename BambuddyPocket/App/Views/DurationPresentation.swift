// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Formatage **unique** d'une durée en secondes vers un libellé lisible et localisé
/// (« 1 h 20 min » / « 12 min » / « 45 s »). Centralise la logique qui était dupliquée entre
/// `ArchivePresentation` et `SupportPresentation`.
enum DurationPresentation {
    /// Libellé d'une durée en secondes.
    ///
    /// - Parameter showsSeconds: si `true`, une durée strictement sous la minute s'affiche en
    ///   secondes (« 45 s ») ; si `false`, elle est arrondie à la minute (« 0 min »).
    /// - Returns: le libellé localisé (les secondes négatives sont traitées comme `0`).
    static func string(seconds: Int, showsSeconds: Bool) -> String {
        let safeSeconds = max(seconds, 0)
        let totalMinutes = safeSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return String(localized: "\(hours) h \(minutes) min")
        }
        if minutes > 0 || !showsSeconds {
            return String(localized: "\(minutes) min")
        }
        return String(localized: "\(safeSeconds) s")
    }
}
