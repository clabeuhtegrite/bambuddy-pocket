// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

@main
struct BambuddyPocketApp: App {
    @State private var model: ServerListModel

    init() {
        _model = State(initialValue: ServerListModel(environment: .live()))
    }

    var body: some Scene {
        WindowGroup {
            ServerListView(model: model)
        }
    }
}
