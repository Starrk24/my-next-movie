//
//  SavedMoviesSync.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 13/11/2026.
//

import Foundation
import SwiftData

@MainActor
func syncSavedMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    try await removeDeletedMoviesFromCloud(context, cloud: cloud)
    try await mergeCloudMoviesToDevice(context, cloud: cloud)
    try await uploadNewMoviesToCloud(context, cloud: cloud)
}

@MainActor
private func removeDeletedMoviesFromCloud(
    _ context: ModelContext,
    cloud: SavedMoviesCloud
) async throws {
    let marks = (try? context.fetch(FetchDescriptor<RemovedSavedMovie>())) ?? []
    let movieIdsToRemove = marks.map { $0.movieId }

    for movieId in movieIdsToRemove {
        try await cloud.removeMovie(movieId)
        removeSavedMovieMarks(context, movieId: movieId)
    }
}

@MainActor
private func mergeCloudMoviesToDevice(
    _ context: ModelContext,
    cloud: SavedMoviesCloud
) async throws {
    let cloudMovies = try await cloud.fetchMovies()
    let cloudMovieIds = Set(cloudMovies.map { $0.id })

    let localMovies = (try? context.fetch(FetchDescriptor<SavedMovie>())) ?? []
    for localMovie in localMovies {
        if localMovie.isInCloud && !cloudMovieIds.contains(localMovie.movieId) {
            context.delete(localMovie)
        }
    }

    let removedMarks = (try? context.fetch(FetchDescriptor<RemovedSavedMovie>())) ?? []
    let removedMovieIds = Set(removedMarks.map { $0.movieId })

    for cloudMovie in cloudMovies {
        if removedMovieIds.contains(cloudMovie.id) {
            continue
        }
        let existingCopies = fetchSavedMovies(context, movieId: cloudMovie.id)
        if let existing = existingCopies.first {
            existing.isInCloud = true
        } else {
            let movie = movieFromCloud(cloudMovie)
            let savedMovie = SavedMovie(
                movie: movie,
                savedAt: cloudMovie.savedAt,
                isInCloud: true
            )
            context.insert(savedMovie)
        }
    }
}

@MainActor
private func uploadNewMoviesToCloud(
    _ context: ModelContext,
    cloud: SavedMoviesCloud
) async throws {
    let descriptor = FetchDescriptor<SavedMovie>(
        predicate: #Predicate { savedMovie in
            savedMovie.isInCloud == false
        }
    )
    let unsyncedMovies = (try? context.fetch(descriptor)) ?? []
    guard !unsyncedMovies.isEmpty else {
        return
    }

    let cloudMoviesToUpload = unsyncedMovies.map { cloudMovieFromSaved($0) }
    let uploadedIds = unsyncedMovies.map { $0.movieId }

    try await cloud.uploadMovies(cloudMoviesToUpload)

    for movieId in uploadedIds {
        let currentCopies = fetchSavedMovies(context, movieId: movieId)
        if let current = currentCopies.first {
            current.isInCloud = true
        } else if fetchRemovedSavedMovies(context, movieId: movieId).isEmpty {
            context.insert(RemovedSavedMovie(movieId: movieId))
        }
    }
}

func cloudMovieFromSaved(_ savedMovie: SavedMovie) -> CloudSavedMovie {
    return CloudSavedMovie(
        id: savedMovie.movieId,
        title: savedMovie.title,
        overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate,
        posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage,
        genreIds: savedMovie.genreIds,
        savedAt: savedMovie.savedAt
    )
}

func movieFromCloud(_ cloudMovie: CloudSavedMovie) -> Movie {
    return Movie(
        id: cloudMovie.id,
        title: cloudMovie.title,
        overview: cloudMovie.overview,
        releaseDate: cloudMovie.releaseDate,
        posterPath: cloudMovie.posterPath,
        voteAverage: cloudMovie.voteAverage,
        genreIds: cloudMovie.genreIds
    )
}
