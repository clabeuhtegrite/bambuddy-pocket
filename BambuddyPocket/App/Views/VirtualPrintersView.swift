// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Gestion des imprimantes virtuelles : émulateurs de périphériques Bambu (développement / tests).
/// Liste, création, édition et suppression.
struct VirtualPrintersView: View {
    @State private var model: VirtualPrintersModel
    @State private var creating = false
    @State private var editing: VirtualPrinter?
    @State private var pendingDelete: VirtualPrinter?

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeVirtualPrintersModel(for: server))
    }

    var body: some View {
        List {
            if let message = model.actionMessage {
                Section { Text(message).font(DSFont.caption).foregroundStyle(DSColor.statusError) }
            }
            ForEach(model.printers) { printer in
                VirtualPrinterRow(printer: printer)
                    .listRowBackground(DSColor.card)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = printer }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDelete = printer
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Virtual printers")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Label("Add virtual printer", systemImage: "plus")
                }
            }
        }
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
        .sheet(isPresented: $creating) {
            VirtualPrinterFormSheet(model: model, editing: nil)
        }
        .sheet(item: $editing) { printer in
            VirtualPrinterFormSheet(model: model, editing: printer)
        }
        .confirmationDialog(
            "Delete this virtual printer?",
            isPresented: deleteBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let printer = pendingDelete {
                    Task { await model.delete(printer) }
                }
                pendingDelete = nil
            }
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else if model.printers.isEmpty, let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t load virtual printers", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        } else if model.printers.isEmpty {
            ContentUnavailableView {
                Label("No virtual printers", systemImage: "printer.dotmatrix")
            } description: {
                Text("Add a virtual printer to emulate a Bambu device for development and testing.")
            }
        }
    }
}

private struct VirtualPrinterRow: View {
    let printer: VirtualPrinter

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text(printer.name)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                DSStatusBadge(
                    VirtualPrinterPresentation.stateLabel(printer),
                    intent: VirtualPrinterPresentation.stateIntent(printer)
                )
            }
            let parts = [
                printer.modelName ?? printer.model,
                VirtualPrinterPresentation.modeLabel(printer.mode),
                printer.serial
            ].compactMap(\.self)
            if !parts.isEmpty {
                Text(parts.joined(separator: " · "))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, DSSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}
