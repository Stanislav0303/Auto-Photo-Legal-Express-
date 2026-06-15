import SwiftUI

@main
struct AutoFotoLegalExpresApp: App {
    var body: some Scene {
        WindowGroup("AutoFoto Legal Expres") {
            MainView()
                .frame(minWidth: 1024, minHeight: 900)
        }
        .windowStyle(.titleBar)
    }
}
