// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import SwiftUI

/// Un composant open source crédité (nom, licence, lien optionnel vers la source).
private struct OpenSourceComponent: Identifiable {
    let name: String
    let license: String
    let url: URL?

    var id: String {
        name
    }
}

/// Écran « À propos » : version, licence, code source et crédits open source complets.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let repositoryURL = URL(string: "https://github.com/clabeuhtegrite/bambuddy-pocket")
    private let bambuddyURL = URL(string: "https://github.com/maziggy/bambuddy")
    private let agplURL = URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")

    /// Composants tiers embarqués (viewer 3D + police), cf. `NOTICE`.
    private let components: [OpenSourceComponent] = [
        .init(name: "three.js", license: "MIT", url: URL(string: "https://github.com/mrdoob/three.js")),
        .init(
            name: "three.js examples (OrbitControls, STLLoader, 3MFLoader)",
            license: "MIT",
            url: URL(string: "https://github.com/mrdoob/three.js")
        ),
        .init(name: "fflate", license: "MIT", url: URL(string: "https://github.com/101arrowz/fflate")),
        .init(name: "Inter", license: "OFL-1.1", url: URL(string: "https://github.com/rsms/inter"))
    ]

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
                    if let agplURL {
                        Link(destination: agplURL) {
                            Label("Read the AGPL v3.0", systemImage: "doc.text")
                        }
                    }
                }

                Section("Built with Bambuddy") {
                    Text(
                        // swiftlint:disable:next line_length
                        "Unaffiliated third-party client for the self-hosted Bambuddy server. BamPocket talks to it only over its public network API and bundles none of its source code."
                    )
                    .font(.footnote)
                    if let bambuddyURL {
                        Link(destination: bambuddyURL) {
                            Label("Bambuddy on GitHub", systemImage: "link")
                        }
                    }
                }

                Section("Open source components") {
                    ForEach(components) { component in
                        componentRow(component)
                    }
                }

                Section {
                    Text("Trademarks belong to their respective owners.")
                        .font(.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle("About")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func componentRow(_ component: OpenSourceComponent) -> some View {
        if let url = component.url {
            Link(destination: url) {
                componentLabel(component)
            }
            .accessibilityElement(children: .combine)
        } else {
            componentLabel(component)
        }
    }

    private func componentLabel(_ component: OpenSourceComponent) -> some View {
        LabeledContent {
            Text(component.license)
                .foregroundStyle(DSColor.textSecondary)
        } label: {
            Text(component.name)
                .foregroundStyle(DSColor.textPrimary)
        }
    }
}
