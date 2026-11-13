//
//  Storage.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 12/11/2026.
//

import Foundation
import SwiftData

// MARK: - Task 1: Saved Movies


func fetchSavedMovies(_ context: ModelContext, movieId: Int) -> [SavedMovie] {
    let descriptor = FetchDescriptor<SavedMovie>(
        predicate: #Predicate { savedMovie in
            savedMovie.movieId == movieId
        }
    )
    return (try? context.fetch(descriptor)) ?? []
}

func fetchRemovedSavedMovies(_ context: ModelContext, movieId: Int) -> [RemovedSavedMovie] {
    let descriptor = FetchDescriptor<RemovedSavedMovie>(
        predicate: #Predicate { removed in
            removed.movieId == movieId
        }
    )
    return (try? context.fetch(descriptor)) ?? []
}

func removeSavedMovieMarks(_ context: ModelContext, movieId: Int) {
    let marks = fetchRemovedSavedMovies(context, movieId: movieId)
    for mark in marks {
        context.delete(mark)
    }
}

func isMovieSaved(_ context: ModelContext, movieId: Int) -> Bool {
    return !fetchSavedMovies(context, movieId: movieId).isEmpty
}

func toggleSavedMovie(_ context: ModelContext, _ movie: Movie, now: Date) {
    let existingCopies = fetchSavedMovies(context, movieId: movie.id)
    if existingCopies.isEmpty {
        removeSavedMovieMarks(context, movieId: movie.id)
        let savedMovie = SavedMovie(movie: movie, savedAt: now, isInCloud: false)
        context.insert(savedMovie)
    } else {
        let wasInCloud = existingCopies.contains { $0.isInCloud }
        for copy in existingCopies {
            context.delete(copy)
        }
        if wasInCloud && fetchRemovedSavedMovies(context, movieId: movie.id).isEmpty {
            context.insert(RemovedSavedMovie(movieId: movie.id))
        }
    }
}

func clearSavedMovies(_ context: ModelContext) {
    let savedMovies = (try? context.fetch(FetchDescriptor<SavedMovie>())) ?? []
    for savedMovie in savedMovies {
        context.delete(savedMovie)
    }

    let removedMarks = (try? context.fetch(FetchDescriptor<RemovedSavedMovie>())) ?? []
    for mark in removedMarks {
        context.delete(mark)
    }
}

func movieFromSaved(_ savedMovie: SavedMovie) -> Movie {
    return Movie(
        id: savedMovie.movieId,
        title: savedMovie.title,
        overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate,
        posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage,
        genreIds: savedMovie.genreIds
    )
}

func moviesFromSaved(_ savedMovies: [SavedMovie]) -> [Movie] {
    var movies: [Movie] = []
    for savedMovie in savedMovies {
        movies.append(movieFromSaved(savedMovie))
    }
    return movies
}

// MARK: - Task 2: Search History

let maxSearchHistoryCount = 10

func recordSearch(_ context: ModelContext, query: String, now: Date) {
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    guard !trimmedQuery.isEmpty else {
        return
    }

    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        predicate: #Predicate { entry in
            entry.query == trimmedQuery
        }
    )
    let existingEntries = (try? context.fetch(descriptor)) ?? []

    if let existingEntry = existingEntries.first {
        existingEntry.searchedAt = now
    } else {
        let newEntry = SearchHistoryEntry(query: trimmedQuery, searchedAt: now)
        context.insert(newEntry)
    }

    removeOldSearches(context)
}

private func removeOldSearches(_ context: ModelContext) {
    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        sortBy: [SortDescriptor(\SearchHistoryEntry.searchedAt, order: .reverse)]
    )
    let allEntries = (try? context.fetch(descriptor)) ?? []

    if allEntries.count > maxSearchHistoryCount {
        for index in maxSearchHistoryCount..<allEntries.count {
            context.delete(allEntries[index])
        }
    }
}

func recentSearches(_ context: ModelContext) -> [SearchHistoryEntry] {
    var descriptor = FetchDescriptor<SearchHistoryEntry>(
        sortBy: [SortDescriptor(\SearchHistoryEntry.searchedAt, order: .reverse)]
    )
    descriptor.fetchLimit = maxSearchHistoryCount
    return (try? context.fetch(descriptor)) ?? []
}

func clearSearchHistory(_ context: ModelContext) {
    let descriptor = FetchDescriptor<SearchHistoryEntry>()
    let allEntries = (try? context.fetch(descriptor)) ?? []
    for entry in allEntries {
        context.delete(entry)
    }
}

// MARK: - Task 3: Response Cache

func storeCachedResponse(_ context: ModelContext, key: String, data: Data, now: Date) {
    let descriptor = FetchDescriptor<CachedResponse>(
        predicate: #Predicate { response in
            response.key == key
        }
    )
    let existingResponses = (try? context.fetch(descriptor)) ?? []

    if let existing = existingResponses.first {
        existing.data = data
        existing.fetchedAt = now
    } else {
        let newResponse = CachedResponse(key: key, data: data, fetchedAt: now)
        context.insert(newResponse)
    }
}

func cachedResponseData(_ context: ModelContext, key: String) -> Data {
    let descriptor = FetchDescriptor<CachedResponse>(
        predicate: #Predicate { response in
            response.key == key
        }
    )
    let existingResponses = (try? context.fetch(descriptor)) ?? []
    return existingResponses.first?.data ?? Data()
}

func fetchWithCacheFallback(
    _ context: ModelContext,
    key: String,
    fetch: () async throws -> Data
) async throws -> Data {
    do {
        let freshData = try await fetch()
        storeCachedResponse(context, key: key, data: freshData, now: .now)
        return freshData
    } catch {
        let cachedData = cachedResponseData(context, key: key)
        if !cachedData.isEmpty {
            return cachedData
        }
        throw error
    }
}
