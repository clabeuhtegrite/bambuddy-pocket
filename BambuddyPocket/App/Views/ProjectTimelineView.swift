// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Chronologie d'un projet : événements horodatés (création, ajouts, impressions…).
struct ProjectTimelineView: View {
    let project: Project
    let model: ProjectListModel

    @State private var events: [TimelineEvent]?
    @State private var hasLoaded = false

    var body: some View {
        List {
            ForEach(events ?? []) { event in
                TimelineRow(event: event)
                    .listRowBackground(DSColor.card)
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Timeline")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task {
            if !hasLoaded {
                await load()
            }
        }
    }

    private func load() async {
        events = await model.timeline(for: project)
        hasLoaded = true
    }

    @ViewBuilder
    private var placeholder: some View {
        if !hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else if events?.isEmpty ?? true {
            ContentUnavailableView(
                "No events",
                systemImage: "clock",
                description: Text("This project has no recorded activity yet.")
            )
        }
    }
}

private struct TimelineRow: View {
    let event: TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(DSColor.accent)
                .padding(.top, DSSpacing.xs)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(event.title)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                if let details = event.details, !details.isEmpty {
                    Text(details)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                if let date = TimelinePresentation.date(from: event.timestamp) {
                    Text(date)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
        .padding(.vertical, DSSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Formatage de présentation des horodatages de chronologie (ISO sans fuseau → date lisible).
enum TimelinePresentation {
    static func date(from raw: String) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: raw) {
            return parsed.formatted(date: .abbreviated, time: .shortened)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let parsed = formatter.date(from: raw) {
            return parsed.formatted(date: .abbreviated, time: .shortened)
        }
        // Horodatage local sans fuseau (p. ex. "2026-06-04T05:31:27").
        let local = DateFormatter()
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let parsed = local.date(from: raw) {
            return parsed.formatted(date: .abbreviated, time: .shortened)
        }
        return raw
    }
}
