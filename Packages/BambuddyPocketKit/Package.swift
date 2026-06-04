// swift-tools-version: 6.0
// SPDX-License-Identifier: AGPL-3.0-or-later
import PackageDescription

let package = Package(
    name: "BambuddyPocketKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "BambuddyPocketDomain", targets: ["BambuddyPocketDomain"]),
        .library(name: "BambuddyPocketNetworking", targets: ["BambuddyPocketNetworking"]),
        .library(name: "BambuddyPocketDesignSystem", targets: ["BambuddyPocketDesignSystem"])
    ],
    targets: [
        // Domain : modèles métier + protocoles de service. Aucune dépendance.
        .target(name: "BambuddyPocketDomain"),
        // Networking : clients REST + WebSocket + caméra. Dépend de Domain.
        .target(
            name: "BambuddyPocketNetworking",
            dependencies: ["BambuddyPocketDomain"]
        ),
        // DesignSystem : tokens, composants. Dépend de Domain (types légers).
        .target(
            name: "BambuddyPocketDesignSystem",
            dependencies: ["BambuddyPocketDomain"]
        ),
        .testTarget(
            name: "BambuddyPocketDomainTests",
            dependencies: ["BambuddyPocketDomain"]
        ),
        .testTarget(
            name: "BambuddyPocketNetworkingTests",
            dependencies: ["BambuddyPocketNetworking"]
        ),
        .testTarget(
            name: "BambuddyPocketDesignSystemTests",
            dependencies: ["BambuddyPocketDesignSystem", "BambuddyPocketDomain"]
        )
    ]
)
