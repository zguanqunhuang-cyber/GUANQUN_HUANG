import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var about: String = ""

    private var profile: UserProfile? {
        if case .authenticated(let session) = appModel.state {
            return session.profile
        }
        return nil
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: Binding(
                    get: { displayName },
                    set: { displayName = $0 }
                ))
                TextField("Email", text: Binding(
                    get: { email },
                    set: { email = $0 }
                ))
                    .keyboardType(.emailAddress)
                TextField("About", text: Binding(
                    get: { about },
                    set: { about = $0 }
                ), axis: .vertical)
                    .lineLimit(1...4)
            }

            Section {
                Button(role: .destructive) {
                    Task { await appModel.signOut() }
                } label: {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("My Profile")
        .task {
            populateFields()
        }
        .onAppear {
            populateFields()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        await appModel.updateProfile(
                            displayName: displayName.isEmpty ? nil : displayName,
                            email: email.isEmpty ? nil : email,
                            about: about.isEmpty ? nil : about
                        )
                    }
                }
                .disabled(profile == nil)
            }
        }
    }

    private func populateFields() {
        guard let profile else { return }
        displayName = profile.displayName
        email = profile.email ?? ""
        about = profile.about ?? ""
    }
}
