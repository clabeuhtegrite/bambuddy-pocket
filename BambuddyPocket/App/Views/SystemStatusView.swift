// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// État du serveur : application, machine, ressources (mémoire/CPU/disque), base de données et
/// diagnostic de santé. Lecture seule (`GET /system/info` + `GET /system/health`).
struct SystemStatusView: View {
    @State private var model: SystemStatusModel

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeSystemStatusModel(for: server))
    }

    var body: some View {
        List {
            if let health = model.health {
                healthSection(health)
            }
            if let app = model.info?.app {
                applicationSection(app)
            }
            if let host = model.info?.system {
                hostSection(host)
            }
            resourcesSection
            if let storage = model.info?.storage {
                storageSection(storage)
            }
            if let database = model.info?.database {
                databaseSection(database)
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Server status")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    private func healthSection(_ health: SystemHealth) -> some View {
        Section("Health") {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: health.hasFindings ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(health.hasFindings ? DSColor.statusWarning : DSColor.statusOK)
                    .accessibilityHidden(true)
                Text(health.hasFindings ? "Issues detected in server logs." : "No issues detected.")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
            if let summary = health.summary, health.hasFindings {
                if let bug = summary.bug, bug > 0 {
                    LabeledContent("Bugs", value: "\(bug)")
                }
                if let env = summary.environment, env > 0 {
                    LabeledContent("Environment", value: "\(env)")
                }
            }
        }
    }

    private func applicationSection(_ app: AppInfo) -> some View {
        Section("Application") {
            if let version = app.version {
                LabeledContent("Version", value: version)
            }
        }
    }

    private func hostSection(_ host: HostInfo) -> some View {
        Section("Host") {
            if let platform = host.platform {
                LabeledContent("Platform", value: platform)
            }
            if let arch = host.architecture {
                LabeledContent("Architecture", value: arch)
            }
            if let hostname = host.hostname {
                LabeledContent("Hostname", value: hostname)
            }
            if let python = host.pythonVersion {
                LabeledContent("Python", value: python)
            }
            if let uptime = host.uptimeFormatted {
                LabeledContent("Uptime", value: uptime)
            }
        }
    }

    @ViewBuilder
    private var resourcesSection: some View {
        if model.info?.memory != nil || model.info?.cpu != nil {
            Section("Resources") {
                if let memory = model.info?.memory {
                    usageRow(
                        "Memory",
                        percent: memory.percentUsed,
                        detail: memory.usedFormatted,
                        total: memory.totalFormatted
                    )
                }
                if let cpu = model.info?.cpu {
                    usageRow("CPU", percent: cpu.percent, detail: cpu.count.map { "\($0) cores" }, total: nil)
                }
            }
        }
    }

    private func storageSection(_ storage: StorageInfo) -> some View {
        Section("Storage") {
            usageRow(
                "Disk",
                percent: storage.diskPercentUsed,
                detail: storage.diskUsedFormatted,
                total: storage.diskTotalFormatted
            )
            if let archive = storage.archiveSizeFormatted {
                LabeledContent("Archive", value: archive)
            }
            if let database = storage.databaseSizeFormatted {
                LabeledContent("Database", value: database)
            }
        }
    }

    private func databaseSection(_ database: DatabaseStats) -> some View {
        Section("Database") {
            if let engine = database.engine {
                LabeledContent("Engine", value: engine)
            }
            if let archives = database.archives {
                LabeledContent("Archives", value: "\(archives)")
            }
            if let printers = database.printers {
                LabeledContent("Printers", value: "\(printers)")
            }
            if let projects = database.projects {
                LabeledContent("Projects", value: "\(projects)")
            }
            if let printTime = database.totalPrintTimeFormatted {
                LabeledContent("Total print time", value: printTime)
            }
        }
    }

    private func usageRow(
        _ label: LocalizedStringKey,
        percent: Double?,
        detail: String?,
        total: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text(label)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                if let percent {
                    Text("\(Int(percent.rounded()))%")
                        .font(DSFont.caption.monospacedDigit())
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            if let percent {
                ProgressView(value: max(0, min(1, percent / 100)))
                    .tint(DSColor.accent)
            }
            if let detail {
                Text(total.map { "\(detail) / \($0)" } ?? detail)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.info == nil {
            ProgressView().tint(DSColor.accent)
        } else if model.info == nil, let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t load server status", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        }
    }
}
