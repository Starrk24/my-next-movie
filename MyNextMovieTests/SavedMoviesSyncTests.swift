//
//  SavedMoviesSyncTests.swift
//  MyNextMovieTests
//
//  Created by Miłosz Siałkowski on 13/11/2026.
//

import Foundation
import SwiftData
import Testing
@testable import MyNextMovie

@MainActor
private final class TestCloud {
    var movies: [CloudSavedMovie] = []
    var isOffline: Bool = false
    var uploadCalls: Int = 0

    var service: SavedMoviesCloud {
        return SavedMoviesCloud(
            fetchMovies: {
                if self.isOffline {
                    throw NoConnection()
                }
                return self.movies.sorted { $0.savedAt > $1.savedAt }
            },
            uploadMovies: { cloudMovies in
                if self.isOffline {
                    throw NoConnection()
                }
                self.uploadCalls += 1
                for movie in cloudMovies {
                    if !self.movies.contains(where: { $0.id == movie.id }) {
                        self.movies.append(movie)
                    }
                }
            },
            removeMovie: { movieId in
                if self.isOffline {
                    throw NoConnection()
                }
                self.movies.removeAll { $0.id == movieId }
            }
        )
    }
}

private func syncTestDate(minutes: Double) -> Date {
    return Date(timeIntervalSince1970: 0).addingTimeInterval(60 * minutes)
}

@MainActor
struct SavedMoviesSyncTests {
    @Test
    func movieSavedOnDeviceGoesToAccount() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let cloud = TestCloud()
        let movie = testMovies[0]

        toggleSavedMovie(context, movie, now: syncTestDate(minutes: 1))
        try await syncSavedMovies(context, cloud: cloud.service)

        let localCopies = fetchSavedMovies(context, movieId: movie.id)
        #expect(localCopies.first?.isInCloud == true)
        #expect(cloud.movies.map { $0.id } == [movie.id])
    }

    @Test
    func movieIsSentOnlyOnce() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let cloud = TestCloud()

        toggleSavedMovie(context, testMovies[0], now: syncTestDate(minutes: 1))
        try await syncSavedMovies(context, cloud: cloud.service)
        try await syncSavedMovies(context, cloud: cloud.service)

        #expect(cloud.uploadCalls == 1)
    }

    @Test
    func movieFromAccountComesToDevice() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let cloud = TestCloud()
        let movie = testMovies[0]

        let savedForCloud = SavedMovie(movie: movie, savedAt: syncTestDate(minutes: 1), isInCloud: true)
        cloud.movies = [cloudMovieFromSaved(savedForCloud)]

        try await syncSavedMovies(context, cloud: cloud.service)

        let localCopies = fetchSavedMovies(context, movieId: movie.id)
        #expect(localCopies.count == 1)
        #expect(localCopies.first?.isInCloud == true)
        #expect(moviesFromSaved(localCopies) == [movie])
    }

    @Test
    func deviceAndAccountListsAreMerged() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let cloud = TestCloud()

        let deviceMovie = testMovies[0]
        let accountMovie = testMovies[1]

        toggleSavedMovie(context, deviceMovie, now: syncTestDate(minutes: 1))
        cloud.movies = [
            cloudMovieFromSaved(
                SavedMovie(movie: accountMovie, savedAt: syncTestDate(minutes: 2), isInCloud: true)
            )
        ]

        try await syncSavedMovies(context, cloud: cloud.service)

        let localMovies = try context.fetch(FetchDescriptor<SavedMovie>())
        let localIds = Set(localMovies.map { $0.movieId })
        let cloudIds = Set(cloud.movies.map { $0.id })

        #expect(localIds == Set([deviceMovie.id, accountMovie.id]))
        #expect(cloudIds == Set([deviceMovie.id, accountMovie.id]))
    }

    @Test
    func movieRemovedOnDeviceIsRemovedFromAccount() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let cloud = TestCloud()
        let movie = testMovies[0]

        toggleSavedMovie(context, movie, now: syncTestDate(minutes: 1))
        try await syncSavedMovies(context, cloud: cloud.service)

        toggleSavedMovie(context, movie, now: syncTestDate(minutes: 2))
        try await syncSavedMovies(context, cloud: cloud.service)

        let marks = try context.fetch(FetchDescriptor<RemovedSavedMovie>())
        #expect(isMovieSaved(context, movieId: movie.id) == false)
        #expect(cloud.movies.isEmpty)
        #expect(marks.isEmpty)
    }

    @Test
    func movieRemovedOnAnotherDeviceIsRemovedHere() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let cloud = TestCloud()
        let movie = testMovies[0]

        toggleSavedMovie(context, movie, now: syncTestDate(minutes: 1))
        try await syncSavedMovies(context, cloud: cloud.service)

        cloud.movies.removeAll()
        try await syncSavedMovies(context, cloud: cloud.service)

        #expect(isMovieSaved(context, movieId: movie.id) == false)
    }

    @Test
    func changesMadeOfflineAreSentWithTheNextSync() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let cloud = TestCloud()
        let firstMovie = testMovies[0]
        let secondMovie = testMovies[1]

        toggleSavedMovie(context, firstMovie, now: syncTestDate(minutes: 1))
        try await syncSavedMovies(context, cloud: cloud.service)

        cloud.isOffline = true
        toggleSavedMovie(context, firstMovie, now: syncTestDate(minutes: 2))
        toggleSavedMovie(context, secondMovie, now: syncTestDate(minutes: 3))

        await #expect(throws: NoConnection.self) {
            try await syncSavedMovies(context, cloud: cloud.service)
        }
        #expect(cloud.movies.map { $0.id } == [firstMovie.id])

        cloud.isOffline = false
        try await syncSavedMovies(context, cloud: cloud.service)

        #expect(cloud.movies.map { $0.id } == [secondMovie.id])
        #expect(isMovieSaved(context, movieId: firstMovie.id) == false)
        #expect(isMovieSaved(context, movieId: secondMovie.id) == true)
    }

    @Test
    func movieRemovedAndSavedAgainOfflineStays() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let cloud = TestCloud()
        let movie = testMovies[0]
        let firstDate = syncTestDate(minutes: 1)
        let secondDate = syncTestDate(minutes: 5)

        toggleSavedMovie(context, movie, now: firstDate)
        try await syncSavedMovies(context, cloud: cloud.service)

        toggleSavedMovie(context, movie, now: syncTestDate(minutes: 2))
        toggleSavedMovie(context, movie, now: secondDate)

        try await syncSavedMovies(context, cloud: cloud.service)

        let localCopies = fetchSavedMovies(context, movieId: movie.id)
        #expect(localCopies.count == 1)
        #expect(localCopies.first?.savedAt == secondDate)
        #expect(cloud.movies.map { $0.id } == [movie.id])
    }
}

@MainActor
struct CloudSavedMovieTests {
    @Test
    func encodesColumnNamesInSnakeCase() throws {
        let movie = testMovies[0]
        let saved = SavedMovie(movie: movie, savedAt: syncTestDate(minutes: 1), isInCloud: true)
        let cloudMovie = cloudMovieFromSaved(saved)

        let data = try JSONEncoder().encode(cloudMovie)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        #expect(jsonString.contains("\"release_date\""))
        #expect(jsonString.contains("\"poster_path\""))
        #expect(jsonString.contains("\"vote_average\""))
        #expect(jsonString.contains("\"genre_ids\""))
        #expect(jsonString.contains("\"saved_at\""))
    }

    @Test
    func cloudCopyKeepsEveryMovieField() {
        let movie = testMovies[0]
        let saved = SavedMovie(movie: movie, savedAt: syncTestDate(minutes: 1), isInCloud: true)
        let cloudMovie = cloudMovieFromSaved(saved)
        let restored = movieFromCloud(cloudMovie)

        #expect(restored == movie)
    }
}
