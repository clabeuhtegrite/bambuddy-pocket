// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Bouton de barre d'outils ouvrant le centre de notifications, avec pastille de non-lus.
struct NotificationsToolbarButton: View {
    let center: ServerNotificationCenter
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let unread = center.unreadCount
            Image(systemName: unread > 0 ? "bell.badge" : "bell")
                .symbolRenderingMode(unread > 0 ? .multicolor : .monochrome)
        }
        .accessibilityLabel("Notifications")
        .accessibilityValue(
            center.unreadCount > 0
                ? Text("\(center.unreadCount) unread")
                : Text("No unread notifications")
        )
    }
}

/// Centre de notifications en-app dérivées du WebSocket pour un serveur : feed horodaté, état
/// lu/non-lu, et effacement. Marque tout comme lu à l'ouverture.
struct NotificationsView: View {
    let center: ServerNotificationCenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(center.notifications) { note in
                    NotificationRow(note: note)
                        .listRowBackground(DSColor.card)
                }
            }
            .dsListBackground()
            .overlay {
                if center.notifications.isEmpty {
                    ContentUnavailableView(
                        "No notifications",
                        systemImage: "bell.slash",
                        description: Text("Print events will appear here as they happen.")
                    )
                }
            }
            .navigationTitle("Notifications")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear", role: .destructive) { center.clear() }
                        .disabled(center.notifications.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { center.markAllAsRead() }
        }
    }
}

private struct NotificationRow: View {
    let note: AppNotification

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: NotificationStyle.icon(note.kind))
                .foregroundStyle(NotificationStyle.color(note.kind))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(NotificationStyle.title(note.kind))
                    .font(DSFont.inter(16, weight: note.isRead ? .regular : .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if !note.isRead {
                Circle()
                    .fill(DSColor.accent)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
            Text(note.date, style: .relative)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textTertiary)
        }
        .padding(.vertical, DSSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    /// Sous-titre : nom de l'imprimante et/ou détail (travail, archive, code HMS).
    private var subtitle: String? {
        let parts = [note.printerName, note.detail].compactMap(\.self).filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Bannière non intrusive affichée en haut de l'écran à l'arrivée d'une notification, qui se
/// replie automatiquement après quelques secondes. Tapotable pour ouvrir le centre.
struct NotificationBanner: View {
    let center: ServerNotificationCenter
    let onTap: () -> Void

    var body: some View {
        Group {
            if let note = center.latestBanner {
                bannerContent(note)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: center.latestBanner)
    }

    private func bannerContent(_ note: AppNotification) -> some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: NotificationStyle.icon(note.kind))
                .foregroundStyle(NotificationStyle.color(note.kind))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(NotificationStyle.title(note.kind))
                    .font(DSFont.inter(14, weight: .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                if let subtitle = bannerSubtitle(note) {
                    Text(subtitle)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DSSpacing.md)
        .dsCardSurface()
        .padding(.horizontal, DSSpacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            center.dismissBanner()
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .task(id: note.id) {
            try? await Task.sleep(for: .seconds(4))
            if center.latestBanner?.id == note.id {
                center.dismissBanner()
            }
        }
    }

    private func bannerSubtitle(_ note: AppNotification) -> String? {
        let parts = [note.printerName, note.detail].compactMap(\.self).filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Habillage partagé d'une catégorie de notification (titre, icône, couleur) — réutilisé par le
/// feed et la bannière.
enum NotificationStyle {
    static func title(_ kind: NotableEventKind) -> LocalizedStringKey {
        switch kind {
        case .printStarted: "Print started"
        case .printCompleted: "Print finished"
        case .missingSpool: "Spool missing"
        case .plateNotEmpty: "Plate not empty"
        case .hmsError: "Printer error"
        case .archiveCreated: "Print archived"
        }
    }

    static func icon(_ kind: NotableEventKind) -> String {
        switch kind {
        case .printStarted: "printer.fill"
        case .printCompleted: "checkmark.circle.fill"
        case .missingSpool: "exclamationmark.triangle.fill"
        case .plateNotEmpty: "tray.full.fill"
        case .hmsError: "exclamationmark.octagon.fill"
        case .archiveCreated: "clock.arrow.circlepath"
        }
    }

    static func color(_ kind: NotableEventKind) -> Color {
        switch kind {
        case .printStarted: DSColor.accent
        case .printCompleted: DSColor.statusOK
        case .missingSpool, .plateNotEmpty: DSColor.statusWarning
        case .hmsError: DSColor.statusError
        case .archiveCreated: DSColor.textMuted
        }
    }
}
