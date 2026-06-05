// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Dérivation d'un **nom de couleur lisible** à partir d'un hex de filament.
///
/// Réplique la logique amont (`frontend/src/utils/colors.ts`) : un bucketing HSL classe le hex dans
/// une famille de couleur (« Red », « Blue », « Light Gray »…), de sorte que **chaque bobine ait
/// toujours un libellé**, même lorsque la couleur n'est pas dans un dictionnaire de noms (#8).
///
/// L'app n'a pas de catalogue couleur runtime (`/api/inventory/colors/map`) côté client ; on se
/// contente donc du repli HSL — qui est précisément le filet de sécurité que la web UI applique
/// quand le catalogue ne couvre pas un hex. Les familles sont localisées (EN/FR/ES/DE).
enum FilamentColorName {
    /// Composantes RGB 0…255 d'un hex exploitable.
    private struct RGB {
        let red: Int
        let green: Int
        let blue: Int
    }

    /// Nom de couleur de base dérivé d'un hex (`RRGGBB` ou `RRGGBBAA`, avec ou sans `#`).
    ///
    /// Renvoie `nil` si le hex est inexploitable (vide, trop court, entièrement transparent),
    /// pour que l'appelant puisse choisir un repli (p. ex. afficher le hex brut).
    static func from(hex: String?) -> String? {
        guard let components = rgb(from: hex) else {
            return nil
        }
        return name(red: components.red, green: components.green, blue: components.blue)
    }

    /// Résout le nom d'affichage d'une couleur de bobine.
    ///
    /// Tente, dans l'ordre :
    /// 1. le `colorName` stocké s'il est lisible (pas un code interne Bambu du type « A06-D0 ») ;
    /// 2. le repli HSL dérivé du hex ;
    /// 3. à défaut, `nil` (l'appelant affichera « — » ou le hex).
    static func resolved(colorName: String?, hex: String?) -> String? {
        if let colorName, !colorName.isEmpty, !isBambuColorCode(colorName) {
            return colorName
        }
        return from(hex: hex)
    }

    /// Un `colorName` ressemblant à un code interne Bambu (« A06-D0 », « X12-Y3 ») n'est pas un nom
    /// lisible : on l'ignore au profit du hex (le même code n'est pas unique entre familles, #857).
    static func isBambuColorCode(_ value: String) -> Bool {
        let pattern = "^[A-Z][0-9]+-[A-Z][0-9]+$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    /// Décompose un hex en composantes 0…255, ou `nil` si inexploitable (vide / court / transparent).
    private static func rgb(from hex: String?) -> RGB? {
        guard var string = hex, !string.isEmpty else {
            return nil
        }
        if string.hasPrefix("#") {
            string.removeFirst()
        }
        let cleaned = string.lowercased()
        guard cleaned.count >= 6 else {
            return nil
        }
        let hexChars = Array(cleaned)
        guard let red = Int(String(hexChars[0 ... 1]), radix: 16),
              let green = Int(String(hexChars[2 ... 3]), radix: 16),
              let blue = Int(String(hexChars[4 ... 5]), radix: 16)
        else {
            return nil
        }
        // Couleur entièrement transparente (`…00`) : pas de couleur exploitable.
        if hexChars.count >= 8, let alpha = Int(String(hexChars[6 ... 7]), radix: 16), alpha == 0 {
            return nil
        }
        return RGB(red: red, green: green, blue: blue)
    }

    /// Classe une couleur RGB (0…255) dans une famille lisible par bucketing HSL (port de
    /// `hexToColorName`). Les seuils sont alignés sur l'amont pour un libellé identique.
    static func name(red: Int, green: Int, blue: Int) -> String {
        let rNorm = Double(red) / 255
        let gNorm = Double(green) / 255
        let bNorm = Double(blue) / 255

        let maxValue = max(rNorm, gNorm, bNorm)
        let minValue = min(rNorm, gNorm, bNorm)
        let lightness = (maxValue + minValue) / 2

        var hue = 0.0
        var saturation = 0.0
        if maxValue != minValue {
            let delta = maxValue - minValue
            saturation = lightness > 0.5 ? delta / (2 - maxValue - minValue) : delta / (maxValue + minValue)
            if maxValue == rNorm {
                hue = ((gNorm - bNorm) / delta + (gNorm < bNorm ? 6 : 0)) / 6
            } else if maxValue == gNorm {
                hue = ((bNorm - rNorm) / delta + 2) / 6
            } else {
                hue = ((rNorm - gNorm) / delta + 4) / 6
            }
        }
        hue *= 360

        return bucket(hue: hue, saturation: saturation, lightness: lightness)
    }

    /// Renvoie le nom de famille selon les seuils HSL amont (« Black », « Brown », « Cyan »…).
    private static func bucket(hue: Double, saturation: Double, lightness: Double) -> String {
        if lightness < 0.15 { return String(localized: "color.black") }
        if lightness > 0.85 { return String(localized: "color.white") }
        if saturation < 0.15 {
            if lightness < 0.4 { return String(localized: "color.darkGray") }
            if lightness > 0.6 { return String(localized: "color.lightGray") }
            return String(localized: "color.gray")
        }
        // Brun : teinte orange/jaune à faible luminosité.
        if hue >= 15, hue < 45, lightness < 0.45 { return String(localized: "color.brown") }
        if hue >= 45, hue < 70, lightness < 0.40 { return String(localized: "color.brown") }
        if hue < 15 || hue >= 345 { return String(localized: "color.red") }
        if hue < 45 { return String(localized: "color.orange") }
        if hue < 70 { return String(localized: "color.yellow") }
        if hue < 150 { return String(localized: "color.green") }
        if hue < 200 { return String(localized: "color.cyan") }
        if hue < 260 { return String(localized: "color.blue") }
        if hue < 290 { return String(localized: "color.purple") }
        return String(localized: "color.pink")
    }
}
