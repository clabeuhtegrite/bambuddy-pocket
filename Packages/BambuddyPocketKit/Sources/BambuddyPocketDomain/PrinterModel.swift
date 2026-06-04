// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Identité normalisée d'un modèle d'imprimante Bambu Lab.
///
/// Miroir fidèle de `backend/app/utils/printer_models.py` (source de vérité amont). Normalise
/// un nom 3MF (« Bambu Lab X1 Carbon »), un code interne (« C11 », « O1D »…) ou un nom court
/// (« X1C ») vers un nom court canonique. Tout modèle inconnu/futur est conservé tel quel (préfixe
/// « Bambu Lab » retiré) pour un dégradé sûr — jamais d'échec.
public struct PrinterModel: Sendable, Hashable {
    /// Nom court canonique (« X1C », « H2D », « A1 Mini »…). Pour un modèle inconnu, le nom brut
    /// nettoyé (préfixe « Bambu Lab » retiré).
    public let shortName: String

    /// Forme normalisée pour comparaison de capacités : majuscules, sans espace ni tiret
    /// (`strip().upper().replace(" ", "").replace("-", "")` côté amont).
    public var normalized: String {
        Self.normalizeForComparison(shortName)
    }

    public init(shortName: String) {
        self.shortName = shortName
    }

    // MARK: Tables amont (miroir de printer_models.py)

    /// `PRINTER_MODEL_MAP` : noms 3MF → noms courts.
    static let modelNameMap: [String: String] = [
        "Bambu Lab X1 Carbon": "X1C",
        "Bambu Lab X1": "X1",
        "Bambu Lab X1E": "X1E",
        "Bambu Lab P1S": "P1S",
        "Bambu Lab P1P": "P1P",
        "Bambu Lab P2S": "P2S",
        "Bambu Lab A1": "A1",
        "Bambu Lab A1 Mini": "A1 Mini",
        "Bambu Lab A1 mini": "A1 Mini",
        "Bambu Lab H2D": "H2D",
        "Bambu Lab H2D Pro": "H2D Pro",
        "Bambu Lab H2C": "H2C",
        "Bambu Lab H2S": "H2S",
        "Bambu Lab X2D": "X2D"
    ]

    /// `PRINTER_MODEL_ID_MAP` : codes internes (slice_info.config) → noms courts.
    static let modelIDMap: [String: String] = [
        // X1 series
        "C11": "X1C",
        "C12": "X1",
        "C13": "X1E",
        // P1 series
        "P1P": "P1P",
        "P1S": "P1S",
        // P2 series
        "P2S": "P2S",
        // X2 series
        "N6": "X2D",
        // A1 series
        "A11": "A1",
        "A12": "A1 Mini",
        "N1": "A1",
        "N2S": "A1 Mini",
        "A04": "A1 Mini",
        // H2 series (Office/H series)
        "O1D": "H2D",
        "O1E": "H2D Pro",
        "O2D": "H2D Pro",
        "O1C": "H2C",
        "O1C2": "H2C",
        "O1S": "H2S"
    ]

    // MARK: Normalisation

    /// Normalise une chaîne pour la comparaison de capacités (miroir amont).
    static func normalizeForComparison(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    /// Construit un `PrinterModel` à partir d'un nom 3MF (`normalize_printer_model`).
    ///
    /// Mappe les noms connus ; sinon retire le préfixe « Bambu Lab ». Renvoie `nil` pour une
    /// entrée vide.
    public static func fromModelName(_ rawModel: String?) -> PrinterModel? {
        guard let rawModel, !rawModel.isEmpty else {
            return nil
        }
        if let short = modelNameMap[rawModel] {
            return PrinterModel(shortName: short)
        }
        let stripped = rawModel
            .replacingOccurrences(of: "Bambu Lab ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : PrinterModel(shortName: stripped)
    }

    /// Construit un `PrinterModel` à partir d'un code interne (`normalize_printer_model_id`).
    ///
    /// Mappe les codes connus ; sinon conserve l'entrée telle quelle (peut déjà être un nom court).
    public static func fromModelID(_ modelID: String?) -> PrinterModel? {
        guard let modelID, !modelID.isEmpty else {
            return nil
        }
        if let short = modelIDMap[modelID] {
            return PrinterModel(shortName: short)
        }
        return PrinterModel(shortName: modelID)
    }

    /// Résolution tolérante depuis une valeur arbitraire (nom 3MF, code interne ou nom court).
    ///
    /// Tente, dans l'ordre : map des noms 3MF, map des codes internes, puis nom court nettoyé.
    /// Cette voie sert le statut/`Printer.model` de l'app, qui peut exposer l'une ou l'autre forme.
    public static func resolve(_ raw: String?) -> PrinterModel? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if let short = modelNameMap[raw] {
            return PrinterModel(shortName: short)
        }
        if let short = modelIDMap[raw] {
            return PrinterModel(shortName: short)
        }
        // Code interne donné sans casse exacte (rare) ou nom court direct.
        let stripped = raw
            .replacingOccurrences(of: "Bambu Lab ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : PrinterModel(shortName: stripped)
    }
}
