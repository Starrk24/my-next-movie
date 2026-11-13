//
//  AccountViewModelTests.swift
//  MyNextMovieTests
//
//  Created by Miłosz Siałkowski on 13/11/2026.
//

import Foundation
import Testing
@testable import MyNextMovie

@MainActor
private final class TestAccount {
    var signedInEmail: String = ""
    var receivedEmail: String = ""
    var isOffline: Bool = false
    var requiresEmailConfirmation: Bool = false
    var syncCalls: Int = 0
    var clearCalls: Int = 0
    var eventsOrder: [String] = []

    func makeViewModel() -> AccountViewModel {
        let service = AccountService(
            signedInEmail: {
                return self.signedInEmail
            },
            signIn: { email, _ in
                if self.isOffline {
                    throw NoConnection()
                }
                self.receivedEmail = email
                self.signedInEmail = email
                return email
            },
            signUp: { email, _ in
                if self.isOffline {
                    throw NoConnection()
                }
                self.receivedEmail = email
                if self.requiresEmailConfirmation {
                    return ""
                }
                self.signedInEmail = email
                return email
            },
            signOut: {
                self.signedInEmail = ""
            }
        )

        return AccountViewModel(
            account: service,
            syncSavedMovies: {
                self.syncCalls += 1
                self.eventsOrder.append("sync")
                if self.isOffline {
                    throw NoConnection()
                }
            },
            clearSavedMovies: {
                self.clearCalls += 1
                self.eventsOrder.append("clear")
            }
        )
    }
}

@MainActor
struct AccountViewModelTests {
    @Test
    func startsSignedOut() {
        let account = TestAccount()
        let viewModel = account.makeViewModel()

        #expect(viewModel.isSignedIn == false)
        #expect(viewModel.signedInEmail == "")
    }

    @Test
    func newAccountNeedsLongEnoughPassword() {
        let account = TestAccount()
        let viewModel = account.makeViewModel()

        viewModel.email = "user@example.com"
        viewModel.password = "short"

        #expect(viewModel.canSignIn == true)
        #expect(viewModel.canSignUp == false)

        viewModel.password = "longenough"
        #expect(viewModel.canSignUp == true)
    }

    @Test
    func signInTrimsEmailClearsPasswordAndSyncs() async {
        let account = TestAccount()
        let viewModel = account.makeViewModel()

        viewModel.email = "  user@example.com  "
        viewModel.password = "secret"

        await viewModel.signIn()

        #expect(account.receivedEmail == "user@example.com")
        #expect(viewModel.signedInEmail == "user@example.com")
        #expect(viewModel.isSignedIn == true)
        #expect(viewModel.password == "")
        #expect(account.syncCalls == 1)
    }

    @Test
    func showsErrorWhenSignInFails() async {
        let account = TestAccount()
        account.isOffline = true
        let viewModel = account.makeViewModel()

        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.signIn()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage.contains("No connection"))
        #expect(viewModel.isSignedIn == false)
    }

    @Test
    func signUpSignsInWhenNoConfirmationIsNeeded() async {
        let account = TestAccount()
        let viewModel = account.makeViewModel()

        viewModel.email = "new@example.com"
        viewModel.password = "password123"

        await viewModel.signUp()

        #expect(viewModel.isSignedIn == true)
        #expect(viewModel.signedInEmail == "new@example.com")
        #expect(viewModel.isWaitingForEmailConfirmation == false)
    }

    @Test
    func signUpWaitsForEmailConfirmation() async {
        let account = TestAccount()
        account.requiresEmailConfirmation = true
        let viewModel = account.makeViewModel()

        viewModel.email = "new@example.com"
        viewModel.password = "password123"

        await viewModel.signUp()

        #expect(viewModel.isWaitingForEmailConfirmation == true)
        #expect(viewModel.isSignedIn == false)
    }

    @Test
    func userFromLastTimeIsSignedInAtOnce() {
        let account = TestAccount()
        account.signedInEmail = "saved@example.com"
        let viewModel = account.makeViewModel()

        #expect(viewModel.isSignedIn == true)
        #expect(viewModel.signedInEmail == "saved@example.com")
    }

    @Test
    func doesNotSyncWhenSignedOut() async {
        let account = TestAccount()
        let viewModel = account.makeViewModel()

        await viewModel.syncSavedMovies()

        #expect(account.syncCalls == 0)
    }

    @Test
    func showsErrorWhenSyncFails() async {
        let account = TestAccount()
        account.signedInEmail = "user@example.com"
        account.isOffline = true
        let viewModel = account.makeViewModel()

        await viewModel.syncSavedMovies()

        #expect(viewModel.syncState == .failed)
        #expect(viewModel.syncErrorMessage.contains("No connection"))
    }

    @Test
    func syncWorksAgainAfterFailure() async {
        let account = TestAccount()
        account.signedInEmail = "user@example.com"
        account.isOffline = true
        let viewModel = account.makeViewModel()

        await viewModel.syncSavedMovies()
        #expect(viewModel.syncState == .failed)

        account.isOffline = false
        await viewModel.syncSavedMovies()
        #expect(viewModel.syncState == .loaded)
    }

    @Test
    func signOutSyncsThenClearsDevice() async {
        let account = TestAccount()
        account.signedInEmail = "user@example.com"
        let viewModel = account.makeViewModel()

        await viewModel.signOut()

        #expect(account.eventsOrder == ["sync", "clear"])
        #expect(account.syncCalls == 1)
        #expect(account.clearCalls == 1)
        #expect(viewModel.isSignedIn == false)
    }
}
