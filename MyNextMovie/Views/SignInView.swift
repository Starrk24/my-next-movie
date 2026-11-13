//
//  SignInView.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 13/11/2026.
//

import SwiftUI

private let headerSymbolSize: CGFloat = 56
private let formMaxWidth: CGFloat = 400

struct SignInView: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: spacingExtraLarge) {
                header
                credentialsFields
                actionButtons
                statusMessage
            }
            .frame(maxWidth: formMaxWidth)
            .padding(spacingExtraLarge)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(spacing: spacingSmall) {
            Image(systemName: symbolNameMovies)
                .font(.system(size: headerSymbolSize))
                .foregroundStyle(.tint)
            Text("My Next Movie")
                .font(.largeTitle.bold())
            Text("Sign in to keep your saved movies across all your devices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, spacingHuge)
    }

    private var credentialsFields: some View {
        VStack(spacing: spacingMedium) {
            TextField("Email", text: $viewModel.email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if viewModel.canSignIn {
                        Task { await viewModel.signIn() }
                    }
                }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: spacingMedium) {
            Button {
                Task { await viewModel.signIn() }
            } label: {
                Text("Sign In")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSignIn)

            Button {
                Task { await viewModel.signUp() }
            } label: {
                Text("Create Account")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canSignUp)
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if viewModel.state == .loading {
            ProgressView()
        } else if viewModel.state == .failed {
            Text(viewModel.errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        } else if viewModel.isWaitingForEmailConfirmation {
            Text("Check your email and click the confirmation link to activate your account.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            Text("New accounts require a password of at least \(minimumPasswordLength) characters.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    SignInView(viewModel: previewAccountViewModel())
}
