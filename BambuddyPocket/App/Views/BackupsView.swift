// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Sauvegardes locales : état (planification, dernière sauvegarde), liste des fichiers et
/// déclenchement d'une sauvegarde immédiate.
struct BackupsView: View {
    @State private var model: BackupsModel

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeBackupsModel(for: server))
    }

    var body: some View {
        List {
            if let status = model.status {
                statusSection(status)
            }
            actionSection
            backupsSection
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Backups")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    private func statusSection(_ status: BackupStatus) -> some View {
        Section("Schedule") {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: status.isScheduleEnabled ? "checkmark.circle.fill" : "pause.circle")
                    .foregroundStyle(status.isScheduleEnabled ? DSColor.statusOK : DSColor.textSecondary)
                Text(status.isScheduleEnabled ? "Scheduled backups enabled" : "Scheduled backups disabled")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
            if status.isScheduleEnabled {
                if let schedule = status.schedule {
                    LabeledContent("Frequency", value: schedule.capitalized)
                }
                if let time = status.time {
                    LabeledContent("Time", value: time)
                }
            }
            if let retention = status.retention {
                LabeledContent("Retention", value: "\(retention)")
            }
            if let last = ArchivePresentation.date(status.lastBackupAt) {
                LabeledContent("Last backup", value: last)
            }
        }
    }

    private var actionSection: some View {
        Section {
            if model.isRunning {
                HStack {
                    ProgressView().tint(DSColor.accent)
                    Text("Backing up…")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                }
            } else {
                Button {
                    Task { await model.runBackup() }
                } label: {
                    Label("Back up now", systemImage: "arrow.down.doc")
                }
            }
        }
    }

    @ViewBuilder
    private var backupsSection: some View {
        if !model.backups.isEmpty {
            Section("Backups") {
                ForEach(model.backups) { backup in
                    BackupRow(backup: backup)
                        .listRowBackground(DSColor.card)
                }
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.status == nil {
            ProgressView().tint(DSColor.accent)
        } else if model.status == nil, let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t load backups", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        }
    }
}

private struct BackupRow: View {
    let backup: BackupFile

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(backup.filename)
                .font(.callout.monospaced())
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
            HStack(spacing: DSSpacing.sm) {
                if let date = ArchivePresentation.date(backup.createdAt) {
                    Text(date)
                }
                if let size = backup.formattedSize {
                    Text(size)
                }
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
