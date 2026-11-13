import Foundation
import Observation

@Observable
class MovieDetailViewModel {
    private(set) var state: LoadState = .idle
    private(set) var details: MovieDetails = emptyMovieDetails
    private(set) var errorMessage: String = ""

    private let movieId: Int
    private let loadDetails: MovieDetailsLoader

    init(movieId: Int, loadDetails: @escaping MovieDetailsLoader) {
        self.movieId = movieId
        self.loadDetails = loadDetails
    }

    func loadIfNeeded() async {
        guard state == .idle else {
            return
        }
        await load()
    }

    func load() async {
        state = .loading
        errorMessage = ""
        do {
            details = try await loadDetails(movieId)
            state = .loaded
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }
}
