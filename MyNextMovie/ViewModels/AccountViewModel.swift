//
//  AccountViewModel.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 13/11/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class AccountViewModel {
    var email: String = ""
    var password: String = ""

    private(set) var signedInEmail: String
    private(set) var state: LoadState = .idle
    private(set) var errorMessage: String = ""
    private(set) var isWaitingForEmailConfirmation: Bool = false

    private(set) var syncState: LoadState = .idle
    private(set) var syncErrorMessage: String = ""

    private let account: AccountService
    private let performSync: () async throws -> Void
    private let clearSavedMovies: @MainActor () -> Void

    private var isSyncing: Bool = false
    private var needsAnotherSync: Bool = false

    init(
        account: AccountService,
        syncSavedMovies: @escaping () async throws -> Void,
        clearSavedMovies: @escaping @MainActor () -> Void
    ) {
        self.account = account
        self.performSync = syncSavedMovies
        self.clearSavedMovies = clearSavedMovies
        self.signedInEmail = account.signedInEmail()
    }

    var isSignedIn: Bool {
        return !signedInEmail.isEmpty
    }

    var canSignIn: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedEmail.isEmpty && !password.isEmpty && state != .loading
    }

    var canSignUp: Bool {
        return canSignIn && password.count >= minimumPasswordLength
    }

    func signIn() async {
        await submit(account.signIn)
    }

    func signUp() async {
        await submit(account.signUp)
    }

    private func submit(_ request: AccountRequest) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty, state != .loading else {
            return
        }

        state = .loading
        errorMessage = ""
        isWaitingForEmailConfirmation = false

        do {
            let returnedEmail = try await request(trimmedEmail, password)
            password = ""
            state = .loaded
            if returnedEmail.isEmpty {
                isWaitingForEmailConfirmation = true
            } else {
                signedInEmail = returnedEmail
                await syncSavedMovies()
            }
        } catch {
            state = .failed
            errorMessage = error.localizedDescription
        }
    }

    func syncSavedMovies() async {
        guard isSignedIn else {
            return
        }
        if isSyncing {
            needsAnotherSync = true
            return
        }

        isSyncing = true
        repeat {
            needsAnotherSync = false
            syncState = .loading
            syncErrorMessage = ""
            do {
                try await performSync()
                syncState = .loaded
            } catch {
                syncState = .failed
                syncErrorMessage = error.localizedDescription
            }
        } while needsAnotherSync && isSignedIn

        isSyncing = false
    }

    func signOut() async {
        await syncSavedMovies()
        try? await account.signOut()
        signedInEmail = ""
        syncState = .idle
        syncErrorMessage = ""
        clearSavedMovies()
    }
}

@MainActor
func previewAccountViewModel(signedInEmail: String = "") -> AccountViewModel {
    let service = AccountService(
        signedInEmail: { signedInEmail },
        signIn: { email, _ in email },
        signUp: { email, _ in email },
        signOut: {}
    )
    return AccountViewModel(
        account: service,
        syncSavedMovies: {},
        clearSavedMovies: {}
    )
}
