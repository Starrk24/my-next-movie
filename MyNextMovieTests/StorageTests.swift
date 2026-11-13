//
//  StorageTests.swift
//  MyNextMovieTests
//
//  Created by Miłosz Siałkowski on 12/11/2026.
//

import Foundation
import SwiftData
import Testing
@testable import MyNextMovie

@MainActor
func makeTestContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Schema(storedModelTypes), configurations: [configuration])
}

@MainActor
struct SavedMovieTests {
    @Test
    func toggleSavesThenRemoves() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let movie = testMovies[0]
        let now = Date(timeIntervalSince1970: 0)

        #expect(isMovieSaved(context, movieId: movie.id) == false)

        toggleSavedMovie(context, movie, now: now)
        #expect(isMovieSaved(context, movieId: movie.id) == true)
        #expect(fetchSavedMovies(context, movieId: movie.id).count == 1)

        toggleSavedMovie(context, movie, now: now)
        #expect(isMovieSaved(context, movieId: movie.id) == false)
        #expect(fetchSavedMovies(context, movieId: movie.id).isEmpty)
    }

    @Test
    func savedCopyKeepsEveryField() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let movie = testMovies[0]
        let now = Date(timeIntervalSince1970: 0)

        toggleSavedMovie(context, movie, now: now)
        let savedCopies = fetchSavedMovies(context, movieId: movie.id)
        let restoredMovies = moviesFromSaved(savedCopies)

        #expect(restoredMovies == [movie])
    }

    @Test
        func removingMovieTheAccountHasLeavesAMark() throws {
            let container = try makeTestContainer()
            let context = container.mainContext
            let movie = testMovies[0]
            let now = Date(timeIntervalSince1970: 0)

            context.insert(SavedMovie(movie: movie, savedAt: now, isInCloud: true))
            toggleSavedMovie(context, movie, now: now)

            let marks = try context.fetch(FetchDescriptor<RemovedSavedMovie>())
            #expect(isMovieSaved(context, movieId: movie.id) == false)
            #expect(marks.map { $0.movieId } == [movie.id])
        }

        @Test
        func removingMovieOnlyOnDeviceLeavesNoMark() throws {
            let container = try makeTestContainer()
            let context = container.mainContext
            let movie = testMovies[0]
            let now = Date(timeIntervalSince1970: 0)

            toggleSavedMovie(context, movie, now: now)
            toggleSavedMovie(context, movie, now: now)

            let marks = try context.fetch(FetchDescriptor<RemovedSavedMovie>())
            #expect(isMovieSaved(context, movieId: movie.id) == false)
            #expect(marks.isEmpty)
        }

    @Test
    func clearRemovesMoviesAndMarks() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 0)

        context.insert(SavedMovie(movie: testMovies[0], savedAt: now, isInCloud: true))
        context.insert(RemovedSavedMovie(movieId: testMovies[1].id))

        clearSavedMovies(context)

        let remainingMovies = try context.fetch(FetchDescriptor<SavedMovie>())
        let remainingMarks = try context.fetch(FetchDescriptor<RemovedSavedMovie>())
        #expect(remainingMovies.isEmpty)
        #expect(remainingMarks.isEmpty)
    }
}

private func testDate(minutes: Double) -> Date {
    return Date(timeIntervalSince1970: 0).addingTimeInterval(60 * minutes)
}

@MainActor
struct SearchHistoryTests {
    @Test
    func newestSearchComesFirst() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: testDate(minutes: 1))
        recordSearch(context, query: "alien", now: testDate(minutes: 2))

        let queries = recentSearches(context).map { $0.query }
        #expect(queries == ["alien", "matrix"])
    }

    @Test
    func repeatedSearchMovesToTop() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: testDate(minutes: 1))
        recordSearch(context, query: "alien", now: testDate(minutes: 2))
        recordSearch(context, query: "matrix", now: testDate(minutes: 3))

        let queries = recentSearches(context).map { $0.query }
        #expect(queries == ["matrix", "alien"])
    }

    @Test
    func emptyAndSpacesAreNotRecorded() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "", now: testDate(minutes: 1))
        recordSearch(context, query: "   ", now: testDate(minutes: 2))
        recordSearch(context, query: "  dune  ", now: testDate(minutes: 3))

        let queries = recentSearches(context).map { $0.query }
        #expect(queries == ["dune"])
    }

    @Test
    func keepsOnlyRecentSearches() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        for step in 1...13 {
            recordSearch(context, query: "movie \(step)", now: testDate(minutes: Double(step)))
        }

        let entries = recentSearches(context)
        #expect(entries.count == 10)
        #expect(entries.first?.query == "movie 13")
    }

    @Test
    func clearRemovesEverything() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: testDate(minutes: 1))
        recordSearch(context, query: "alien", now: testDate(minutes: 2))
        clearSearchHistory(context)

        #expect(recentSearches(context).isEmpty)
    }
}

@MainActor
struct ResponseCacheTests {
    @Test
    func missingKeyGivesEmptyData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let data = cachedResponseData(context, key: "popular")
        #expect(data.isEmpty)
    }

    @Test
    func storingAgainReplacesData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        storeCachedResponse(
            context,
            key: "popular",
            data: Data("first".utf8),
            now: testDate(minutes: 1)
        )
        storeCachedResponse(
            context,
            key: "popular",
            data: Data("second".utf8),
            now: testDate(minutes: 2)
        )

        let count = try context.fetchCount(FetchDescriptor<CachedResponse>())
        let stored = cachedResponseData(context, key: "popular")

        #expect(count == 1)
        #expect(String(data: stored, encoding: .utf8) == "second")
    }

    @Test
    func freshAnswerIsReturnedAndCached() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let expectedData = Data("{\"results\": []}".utf8)

        let returnedData = try await fetchWithCacheFallback(context, key: "popular") {
            return expectedData
        }

        #expect(returnedData == expectedData)
        #expect(cachedResponseData(context, key: "popular") == expectedData)
    }

    @Test
    func cachedAnswerIsReturnedWhenOffline() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let cachedData = Data("{\"results\": []}".utf8)

        storeCachedResponse(context, key: "popular", data: cachedData, now: testDate(minutes: 1))

        let returnedData = try await fetchWithCacheFallback(context, key: "popular") {
            throw NoConnection()
        }

        #expect(returnedData == cachedData)
    }

    @Test
    func errorIsRethrownWhenNothingCached() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        await #expect(throws: NoConnection.self) {
            try await fetchWithCacheFallback(context, key: "popular") {
                throw NoConnection()
            }
        }
    }
}
