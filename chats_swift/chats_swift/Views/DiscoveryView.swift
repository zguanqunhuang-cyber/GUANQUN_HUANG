import SwiftUI

struct DiscoveryView: View {
    private enum DiscoverRoute: Hashable {
        case studio
    }

    let profile: UserProfile
    @State private var navigationPath = NavigationPath()
    @State private var showingCreateHint = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Discover")
            .alert("Create 功能即将到来", isPresented: $showingCreateHint) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("我们正在为你准备更强大的创作体验，敬请期待。")
            }
            .navigationDestination(for: DiscoverRoute.self) { route in
                if route == .studio {
                    StudioHTMLView()
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                showingCreateHint = true
            } label: {
                actionButtonLabel(
                    title: "Create",
                    subtitle: "记录灵感",
                    systemImage: "plus.circle.fill",
                    colors: [.indigo, .pink]
                )
            }

            Button {
                navigationPath.append(DiscoverRoute.studio)
            } label: {
                actionButtonLabel(
                    title: "Studio",
                    subtitle: "发现作品",
                    systemImage: "sparkles",
                    colors: [.mint, .cyan]
                )
            }
        }
    }

    private func actionButtonLabel(
        title: String,
        subtitle: String,
        systemImage: String,
        colors: [Color]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}
