// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

/// Écran « À propos » : version, licence, code source et crédits open source.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let repositoryURL = URL(string: "https://github.com/clabeuhtegrite/bambuddy-pocket")

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Version", value: version)
                    if let repositoryURL {
                        Link(destination: repositoryURL) {
                            Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                }

                Section("License") {
                    Text("Free software under the GNU AGPL v3.0 (App Store exception).")
                        .font(.footnote)
                }

                Section("Third-party components") {
                    LabeledContent("three.js", value: "MIT")
                    LabeledContent("fflate", value: "MIT")
                }

                Section {
                    Text("Unaffiliated third-party client. Trademarks belong to their respective owners.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("About")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
