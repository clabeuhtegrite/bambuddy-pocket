// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("Support")
struct SupportTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.bambuddy().decode(type, from: Data(json.utf8))
    }

    /// Charge réelle observée sur le Docker (`GET /support/debug-logging`) journal désactivé.
    @Test("DebugLoggingState décode l'état désactivé")
    func decodesDisabledDebug() throws {
        let state = try decode(
            DebugLoggingState.self,
            #"{"enabled":false,"enabled_at":null,"duration_seconds":null}"#
        )
        #expect(state.enabled == false)
        #expect(state.enabledAt == nil)
        #expect(state.durationSeconds == nil)
    }

    @Test("DebugLoggingState décode l'état activé avec durée")
    func decodesEnabledDebug() throws {
        let state = try decode(
            DebugLoggingState.self,
            #"{"enabled":true,"enabled_at":"2026-06-04T14:00:00+00:00","duration_seconds":120}"#
        )
        #expect(state.enabled == true)
        #expect(state.durationSeconds == 120)
    }

    /// Charge réelle observée sur le Docker (`GET /support/logs`).
    @Test("LogsResponse décode les entrées de journal réelles")
    func decodesLogs() throws {
        let json = #"""
        {"entries":[{"timestamp":"2026-06-04 14:34:59,151","level":"INFO",
        "logger_name":"backend.app.services.bambu_mqtt","message":"Probing developer mode"}],
        "total_in_file":24895,"filtered_count":1}
        """#
        let response = try decode(LogsResponse.self, json)
        #expect(response.totalInFile == 24895)
        #expect(response.filteredCount == 1)
        let entry = try #require(response.entries.first)
        #expect(entry.level == "INFO")
        #expect(entry.loggerName == "backend.app.services.bambu_mqtt")
        #expect(entry.message == "Probing developer mode")
    }

    @Test("LogEntry produit un identifiant stable pour des contenus identiques")
    func stableLogIdentifier() {
        let a = LogEntry(timestamp: "t", level: "INFO", loggerName: "n", message: "m")
        let b = LogEntry(timestamp: "t", level: "INFO", loggerName: "n", message: "m")
        let c = LogEntry(timestamp: "t", level: "WARNING", loggerName: "n", message: "m")
        #expect(a.id == b.id)
        #expect(a.id != c.id)
    }
}
