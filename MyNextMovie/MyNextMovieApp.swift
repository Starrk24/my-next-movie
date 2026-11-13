import SwiftData
import SwiftUI

@main
struct MyNextMovieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: storedModelTypes)
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var accountViewModel: AccountViewModel?

    var body: some View {
        Group {
            if let accountViewModel {
                if accountViewModel.isSignedIn {
                    AppTabs(
                        account: accountViewModel,
                        loadPopularMovies: loadPopularMoviesWithCache,
                        loadDetails: loadDetailsWithCache
                    )
                } else {
                    SignInView(viewModel: accountViewModel)
                }
            }
        }
        .onAppear {
            if accountViewModel == nil {
                accountViewModel = makeAccountViewModel()
            }
        }
    }

    private func makeAccountViewModel() -> AccountViewModel {
        let viewModel = AccountViewModel(
            account: supabaseAccountService,
            syncSavedMovies: {
                try await syncSavedMovies(modelContext, cloud: supabaseSavedMoviesCloud)
            },
            clearSavedMovies: {
                clearSavedMovies(modelContext)
            }
        )
        #if DEBUG
            viewModel.email = testAccountEmail
            viewModel.password = testAccountPassword
        #endif
        return viewModel
    }

    private func loadPopularMoviesWithCache() async throws -> [Movie] {
        return try await loadPopularMovies(cache: modelContext)
    }

    private func loadDetailsWithCache(movieId: Int) async throws -> MovieDetails {
        return try await loadTMDBMovieDetails(movieId: movieId, cache: modelContext)
    }
}

private struct AppTabs: View {
    let account: AccountViewModel
    let loadPopularMovies: MovieLoader
    let loadDetails: MovieDetailsLoader

    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<SavedMovie> { $0.isInCloud == false })
    private var unsyncedSavedMovies: [SavedMovie]
    @Query private var removedSavedMovies: [RemovedSavedMovie]

    private var unsyncedChangesCount: Int {
        return unsyncedSavedMovies.count + removedSavedMovies.count
    }

    var body: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) {
                MovieListView(
                    viewModel: MovieListViewModel(loadMovies: loadPopularMovies),
                    loadDetails: loadDetails
                )
            }
            Tab("Saved", systemImage: symbolNameSaved) {
                SavedMoviesView(loadDetails: loadDetails)
            }
            Tab("Account", systemImage: symbolNameAccount) {
                AccountView(viewModel: account)
            }
            Tab("Search", systemImage: symbolNameSearch, role: .search) {
                SearchView(
                    viewModel: SearchViewModel(searchMovies: searchTMDBMovies),
                    loadDetails: loadDetails
                )
            }
        }
        .task {
            await account.syncSavedMovies()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await account.syncSavedMovies() }
            }
        }
        .onChange(of: unsyncedChangesCount) { oldCount, newCount in
            if newCount > oldCount {
                Task { await account.syncSavedMovies() }
            }
        }
    }
}
