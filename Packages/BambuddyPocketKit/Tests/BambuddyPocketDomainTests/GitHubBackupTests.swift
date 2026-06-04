// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("GitHubBackup")
struct GitHubBackupTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.bambuddy().decode(type, from: Data(json.utf8))
    }

    /// Charge réelle observée sur le Docker (`GET /github-backup/status`) sans configuration.
    @Test("GitHubBackupStatus décode l'état non configuré")
    func decodesUnconfiguredStatus() throws {
        let json = #"""
        {"configured":false,"enabled":false,"is_running":false,"progress":null,
        "last_backup_at":null,"last_backup_status":null,"next_scheduled_run":null}
        """#
        let status = try decode(GitHubBackupStatus.self, json)
        #expect(status.configured == false)
        #expect(status.enabled == false)
        #expect(status.isRunning == false)
    }

    /// Charge réelle observée sur le Docker (`GET /github-backup/config`) après seed (token masqué).
    @Test("GitHubBackupConfig décode la config réelle (token non renvoyé)")
    func decodesConfig() throws {
        let json = #"""
        {"id":1,"repository_url":"https://github.com/example/bambuddy-backup","has_token":true,
        "branch":"main","provider":"github","allow_insecure_http":false,"schedule_enabled":true,
        "schedule_type":"daily","backup_kprofiles":true,"backup_cloud_profiles":true,
        "backup_settings":false,"backup_spools":false,"backup_archives":false,"enabled":true,
        "last_backup_at":null,"last_backup_status":null,"last_backup_message":null,
        "last_backup_commit_sha":null,"next_scheduled_run":null,"created_at":"2026-06-04T11:56:50",
        "updated_at":"2026-06-04T11:56:50"}
        """#
        let config = try decode(GitHubBackupConfig.self, json)
        #expect(config.id == 1)
        #expect(config.repositoryUrl == "https://github.com/example/bambuddy-backup")
        #expect(config.hasToken == true)
        #expect(config.branch == "main")
        #expect(config.provider == "github")
        #expect(config.scheduleEnabled == true)
        #expect(config.scheduleType == "daily")
        #expect(config.backupKprofiles == true)
        #expect(config.enabled == true)
    }

    @Test("GitHubBackupConfig décode null en optionnel absent")
    func decodesNullConfig() throws {
        let config = try decode(GitHubBackupConfig?.self, "null")
        #expect(config == nil)
    }

    /// Charge réelle observée sur le Docker (`GET /github-backup/logs`) après seed.
    @Test("GitHubBackupLog décode une entrée de journal réelle")
    func decodesLog() throws {
        let json = #"""
        {"id":1,"config_id":1,"started_at":"2026-06-04T11:57:10",
        "completed_at":"2026-06-04T11:57:10.094671","status":"success","trigger":"manual",
        "commit_sha":"abc1234","files_changed":7,"error_message":null}
        """#
        let log = try decode(GitHubBackupLog.self, json)
        #expect(log.id == 1)
        #expect(log.configId == 1)
        #expect(log.status == "success")
        #expect(log.trigger == "manual")
        #expect(log.commitSha == "abc1234")
        #expect(log.filesChanged == 7)
    }

    @Test("GitHubBackupConfigCreate encode le jeton et les options en snake_case")
    func encodesCreate() throws {
        let create = GitHubBackupConfigCreate(
            repositoryUrl: "https://github.com/me/backup",
            accessToken: "tok",
            scheduleEnabled: true,
            allowInsecureHttp: false
        )
        let data = try JSONEncoder.bambuddy().encode(create)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["repository_url"] as? String == "https://github.com/me/backup")
        #expect(json["access_token"] as? String == "tok")
        #expect(json["schedule_enabled"] as? Bool == true)
        #expect(json["allow_insecure_http"] as? Bool == false)
    }
}
