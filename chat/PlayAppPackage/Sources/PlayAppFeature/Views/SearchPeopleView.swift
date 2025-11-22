import SwiftUI

struct SearchPeopleView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [UserProfile] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    let onSelected: (UserProfile) -> Void

    var body: some View {
        List {
            ForEach(results) { profile in
                Button {
                    onSelected(profile)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(.headline)
                        if let email = profile.email, !email.isEmpty {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if let phone = profile.phone, !phone.isEmpty {
                            Text(phone)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .overlay {
            if isSearching {
                ProgressView()
            } else if results.isEmpty, !query.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Try a different name or email.")
                )
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Name or email")
        .onChange(of: query) { _, newValue in
            debounceSearch(text: newValue)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func debounceSearch(text: String) {
        searchTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task { [trimmed] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            let found = await appModel.searchProfiles(matching: trimmed)
            await MainActor.run {
                results = found
                isSearching = false
            }
        }
    }
}
