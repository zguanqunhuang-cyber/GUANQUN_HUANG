import SwiftUI

public struct ContentView: View {
    @StateObject private var appModel: AppViewModel

    public init(configuration: SupabaseConfiguration) {
        _appModel = StateObject(wrappedValue: AppViewModel(configuration: configuration))
    }

    public init() {
        self.init(configuration: .placeholder)
    }

    public var body: some View {
        RootView()
            .environmentObject(appModel)
    }
}
