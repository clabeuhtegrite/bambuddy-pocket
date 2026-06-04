// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Feuille de déplacement d'un fichier vers un dossier (ou la racine).
struct LibraryMoveSheet: View {
    let file: LibraryFile
    let model: LibraryListModel

    @Environment(\.dismiss) private var dismiss

    /// Liste aplatie des dossiers (avec indentation par profondeur) pour un choix simple.
    private var flatFolders: [(folder: FolderTreeItem, depth: Int)] {
        var result: [(FolderTreeItem, Int)] = []
        func walk(_ folders: [FolderTreeItem], depth: Int) {
            for folder in folders where folder.externalReadonly != true {
                result.append((folder, depth))
                walk(folder.subfolders, depth: depth + 1)
            }
        }
        walk(model.folders, depth: 0)
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task {
                            await model.move(file, toFolder: nil)
                            dismiss()
                        }
                    } label: {
                        Label("Root", systemImage: "house")
                    }
                    .listRowBackground(DSColor.card)
                }
                Section("Folders") {
                    ForEach(flatFolders, id: \.folder.id) { entry in
                        Button {
                            Task {
                                await model.move(file, toFolder: entry.folder.id)
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: DSSpacing.sm) {
                                Image(systemName: "folder")
                                    .foregroundStyle(DSColor.accent)
                                Text(entry.folder.name)
                                    .foregroundStyle(DSColor.textPrimary)
                            }
                            .padding(.leading, CGFloat(entry.depth) * DSSpacing.md)
                        }
                        .listRowBackground(DSColor.card)
                    }
                }
            }
            .dsListBackground()
            .navigationTitle("Move file")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
