//
//  SavedMoviesView.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 12/11/2026.
//

import SwiftData
import SwiftUI

struct SavedMoviesView: View {
    @Query(sort: \SavedMovie.savedAt, order: .reverse) private var savedMovies: [SavedMovie]
    private let loadDetails: MovieDetailsLoader

    init(loadDetails: @escaping MovieDetailsLoader) {
        self.loadDetails = loadDetails
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Saved")
                .navigationDestination(for: Movie.self) { movie in
                    MovieDetailView(movie: movie, loadDetails: loadDetails)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if savedMovies.isEmpty {
            ContentUnavailableView(
                "No saved movies",
                systemImage: symbolNameSaved,
                description: Text("Tap the bookmark on a movie's details screen to save it for later.")
            )
        } else {
            MovieGrid(title: "Watch Later", movies: moviesFromSaved(savedMovies))
        }
    }
}

struct SaveMovieButton: View {
    let movie: Movie
    @Environment(\.modelContext) private var modelContext
    @Query private var savedCopies: [SavedMovie]

    init(movie: Movie) {
        self.movie = movie
        let movieId = movie.id
        _savedCopies = Query(filter: #Predicate { savedMovie in savedMovie.movieId == movieId })
    }

    private var isSaved: Bool {
        return !savedCopies.isEmpty
    }

    var body: some View {
        Button {
            toggleSavedMovie(modelContext, movie, now: .now)
        } label: {
            Label(
                isSaved ? "Remove from Saved" : "Save Movie",
                systemImage: isSaved ? symbolNameSavedFilled : symbolNameSaved
            )
        }
    }
}

#Preview {
    SavedMoviesView(loadDetails: fetchMovieDetails)
        .modelContainer(for: storedModelTypes, inMemory: true)
}
