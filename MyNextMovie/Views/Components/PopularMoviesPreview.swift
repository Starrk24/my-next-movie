import SwiftUI

struct PopularMoviesPreview<Content: View>: View {
    @ViewBuilder let content: ([Movie]) -> Content

    @State private var movies: [Movie] = []
    @State private var errorMessage: String = ""
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if !movies.isEmpty {
                content(movies)
            }
        }
        .task {
            await loadMovies()
        }
    }

    private func loadMovies() async {
        isLoading = true
        errorMessage = ""
        do {
            movies = try await fetchPopularMovies()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
