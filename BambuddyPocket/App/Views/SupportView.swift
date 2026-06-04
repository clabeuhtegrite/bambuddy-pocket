// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Support / diagnostic : bascule du journal de débogage et consultation du journal applicatif
/// du serveur (filtrage par niveau, recherche, effacement).
struct SupportView: View {
    @State private var model: SupportModel
    @State private var searchText = ""
    @State private var confirmingClear = false

    private let levels = ["DEBUG", "INFO", "WARNING", "ERROR"]

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeSupportModel(for: server))
    }

    var body: some View {
        List {
            debugSection
            filterSection
            logsSection
            if let message = model.actionMessage {
                Section { Text(message).font(DSFont.caption).foregroundStyle(DSColor.statusError) }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Support")
        .toolbarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: Text("Search logs"))
        .onSubmit(of: .search) { Task { await model.search(searchText) } }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                Task { await model.search("") }
            }
        }
        .toolbar {
            if !model.entries.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        confirmingClear = true
                    } label: {
                        Label("Clear logs", systemImage: "trash")
                    }
                }
            }
        }
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
        .confirmationDialog(
            "Clear server logs?",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear logs", role: .destructive) {
                Task { await model.clearLogs() }
            }
        } message: {
            Text("This empties the server log file. It cannot be undone.")
        }
    }

    private var debugSection: some View {
        Section {
            Toggle(isOn: debugBinding) {
                Text("Debug logging").font(DSFont.body).foregroundStyle(DSColor.textPrimary)
            }
            .disabled(model.isBusy)
            if let state = model.debugState, state.enabled, let duration = state.durationSeconds {
                LabeledContent("Active for", value: SupportPresentation.duration(seconds: duration))
            }
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("Verbose logging helps diagnose issues. Turn it off when you are done.")
        }
    }

    private var filterSection: some View {
        Section("Log level") {
            Picker("Level", selection: levelBinding) {
                Text("All").tag(String?.none)
                ForEach(levels, id: \.self) { level in
                    Text(level).tag(String?.some(level))
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var logsSection: some View {
        if model.entries.isEmpty, model.hasLoaded {
            Section("Logs") {
                Text("No log entries match the current filter.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        } else if !model.entries.isEmpty {
            Section {
                ForEach(model.entries) { entry in
                    LogEntryRow(entry: entry)
                        .listRowBackground(DSColor.card)
                }
            } header: {
                Text("Logs (\(model.totalInFile) total)")
            }
        }
    }

    private var debugBinding: Binding<Bool> {
        Binding(
            get: { model.debugState?.enabled ?? false },
            set: { value in Task { await model.setDebugLogging(value) } }
        )
    }

    private var levelBinding: Binding<String?> {
        Binding(
            get: { model.levelFilter },
            set: { value in Task { await model.applyLevel(value) } }
        )
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else if model.entries.isEmpty, model.debugState == nil, let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t load diagnostics", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        }
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                DSStatusBadge(entry.level ?? "—", intent: SupportPresentation.levelIntent(entry.level))
                Spacer()
                if let timestamp = entry.timestamp {
                    Text(timestamp).font(.caption2.monospaced()).foregroundStyle(DSColor.textSecondary)
                }
            }
            if let logger = entry.loggerName {
                Text(logger).font(.caption.monospaced()).foregroundStyle(DSColor.textSecondary).lineLimit(1)
            }
            if let message = entry.message {
                Text(message).font(DSFont.caption).foregroundStyle(DSColor.textPrimary).lineLimit(4)
            }
        }
        .padding(.vertical, DSSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}
