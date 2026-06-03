// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Feed des notifications en-app dérivées du WebSocket pour un serveur.
struct NotificationsView: View {
    let notifications: [AppNotification]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(notifications) { note in
                    NotificationRow(note: note)
                }
            }
            .overlay {
                if notifications.isEmpty {
                    ContentUnavailableView("No notifications", systemImage: "bell.slash")
                }
            }
            .navigationTitle("Notifications")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct NotificationRow: View {
    let note: AppNotification

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                if let printer = note.printerName {
                    Text(printer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(note.date, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DSSpacing.xs)
    }

    private var title: LocalizedStringKey {
        switch note.kind {
        case .printStarted: "Print started"
        case .printCompleted: "Print finished"
        case .missingSpool: "Spool missing"
        case .plateNotEmpty: "Plate not empty"
        }
    }

    private var icon: String {
        switch note.kind {
        case .printStarted: "printer.fill"
        case .printCompleted: "checkmark.circle.fill"
        case .missingSpool: "exclamationmark.triangle.fill"
        case .plateNotEmpty: "tray.full.fill"
        }
    }

    private var color: Color {
        switch note.kind {
        case .printStarted: .blue
        case .printCompleted: .green
        case .missingSpool, .plateNotEmpty: .orange
        }
    }
}
