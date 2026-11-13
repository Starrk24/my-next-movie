//
//  AccountView.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 13/11/2026.
//

import SwiftUI

struct AccountView: View {
    let viewModel: AccountViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Signed in as") {
                    Text(viewModel.signedInEmail)
                }

                Section("Saved movies") {
                    syncStatusContent
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await viewModel.signOut() }
                    }
                } footer: {
                    Text("Your saved movies stay on your account and are removed from this device.")
                }
            }
            .navigationTitle("Account")
        }
    }

    @ViewBuilder
    private var syncStatusContent: some View {
        switch viewModel.syncState {
        case .idle, .loading:
            HStack(spacing: spacingMedium) {
                ProgressView()
                Text("Syncing with your account")
                    .foregroundStyle(.secondary)
            }
        case .loaded:
            Text("In sync with your account")
        case .failed:
            VStack(alignment: .leading, spacing: spacingSmall) {
                Text(viewModel.syncErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                Button("Try again") {
                    Task { await viewModel.syncSavedMovies() }
                }
            }
        }
    }
}

#Preview {
    AccountView(viewModel: previewAccountViewModel(signedInEmail: testAccountEmail))
}
