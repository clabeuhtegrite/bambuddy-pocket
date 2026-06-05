// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// Source d'un lancement d'impression : un fichier de bibliothèque tranché, ou la réimpression
/// d'une archive. Porte le nom à afficher pour la feuille de confirmation.
enum PrintSource: Equatable {
    case libraryFile(id: Int, name: String)
    case archive(id: Int, name: String)

    var displayName: String {
        switch self {
        case let .libraryFile(_, name), let .archive(_, name): name
        }
    }
}

/// View-model de la feuille « Imprimer » : charge les imprimantes (avec leur connectivité), tient
/// les options, puis dispatche l'impression vers le serveur. Réutilisable depuis le détail d'un
/// fichier de bibliothèque **et** d'une archive.
///
/// Lecture seule jusqu'au tap explicite sur « Imprimer » : aucune mutation n'est émise tant que
/// l'utilisateur n'a pas confirmé une cible.
@MainActor
@Observable
final class PrintDispatchModel: Identifiable {
    /// Identité stable de la feuille (pour `sheet(item:)`).
    nonisolated let id = UUID()

    /// Imprimante candidate : identité + connectivité (seules les connectées sont sélectionnables).
    struct Target: Identifiable, Hashable {
        let printer: Printer
        let isConnected: Bool
        var id: Int {
            printer.id
        }
    }

    let source: PrintSource

    private(set) var targets: [Target] = []
    private(set) var hasLoaded = false
    private(set) var isDispatching = false
    var selectedPrinterID: Int?
    var options = PrintLaunchOptions()
    /// Message d'erreur de chargement / de dispatch (traduit), `nil` si tout va bien.
    var error: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(source: PrintSource, server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.source = source
        self.server = server
        self.connectionFactory = connectionFactory
    }

    /// `true` quand une cible connectée est sélectionnée et qu'aucun dispatch n'est en cours.
    var canDispatch: Bool {
        guard !isDispatching, let id = selectedPrinterID else { return false }
        return targets.first { $0.id == id }?.isConnected ?? false
    }

    /// Charge les imprimantes et leur connectivité. Présélectionne la première imprimante connectée.
    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let printers = try await client.printers()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            var loaded: [Target] = []
            for printer in printers {
                let connected = await (try? client.printerStatus(id: printer.id))?.connected ?? false
                loaded.append(Target(printer: printer, isConnected: connected))
            }
            targets = loaded
            if selectedPrinterID == nil {
                selectedPrinterID = loaded.first { $0.isConnected }?.id ?? loaded.first?.id
            }
            error = nil
        } catch {
            self.error = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Dispatche l'impression vers l'imprimante sélectionnée. Renvoie `true` au succès (la vue ferme
    /// alors la feuille). En cas d'échec, `error` est renseigné et la feuille reste ouverte.
    func dispatch() async -> Bool {
        guard let printerID = selectedPrinterID else { return false }
        isDispatching = true
        defer { isDispatching = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            switch source {
            case let .libraryFile(id, _):
                _ = try await client.printLibraryFile(
                    id: id,
                    printerID: printerID,
                    request: FilePrintRequest(options: options)
                )
            case let .archive(id, _):
                _ = try await client.reprintArchive(
                    id: id,
                    printerID: printerID,
                    request: ReprintRequest(options: options)
                )
            }
            error = nil
            return true
        } catch {
            self.error = ErrorMessage.text(for: error)
            return false
        }
    }
}
