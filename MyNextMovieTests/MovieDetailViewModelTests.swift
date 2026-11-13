import Foundation
import Testing
@testable import MyNextMovie


@MainActor
struct MovieDetailViewModelTests {
    @Test
    func startsIdleWithEmptyDetails() {
        let viewModel = MovieDetailViewModel(movieId: 603) { _ in
            return testMovieDetails
        }

        #expect(viewModel.state == .idle)
        #expect(viewModel.details.credits.cast.isEmpty)
    }

    @Test
    func loadsDetailsOfItsMovie() async {
        var requestedMovieId = 0
        let viewModel = MovieDetailViewModel(movieId: 603) { movieId in
            requestedMovieId = movieId
            return testMovieDetails
        }

        await viewModel.load()

        #expect(requestedMovieId == 603)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.details.tagline == "Believe the unbelievable.")
    }

    @Test
    func showsErrorWhenLoadingFails() async {
        let viewModel = MovieDetailViewModel(movieId: 603) { _ in
            throw NoConnection()
        }

        await viewModel.load()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage.contains("No connection"))
    }

    @Test
    func loadIfNeededLoadsOnlyOnce() async {
        var loadCalls = 0
        let viewModel = MovieDetailViewModel(movieId: 603) { _ in
            loadCalls += 1
            return testMovieDetails
        }

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(loadCalls == 1)
    }
}
