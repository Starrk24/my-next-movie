import Foundation
import Testing
@testable import MyNextMovie

private let matrixDetailsJSON = """
{
  "id": 603,
  "tagline": "Believe the unbelievable.",
  "runtime": 136,
  "credits": {
    "cast": [
      {"id": 6384, "name": "Keanu Reeves", "character": "Neo", "profile_path": "/8RZL.jpg"},
      {"id": 6385, "name": "Extra Actor", "character": "Agent", "profile_path": null}
    ],
    "crew": [
      {"id": 9340, "name": "Lana Wachowski", "job": "Director"},
      {"id": 9340, "name": "Lana Wachowski", "job": "Director"},
      {"id": 9339, "name": "Lilly Wachowski", "job": "Director"},
      {"id": 1234, "name": "Joel Silver", "job": "Producer"}
    ]
  },
  "videos": {
    "results": [
      {"key": "unofficial123", "site": "YouTube", "type": "Trailer", "official": false},
      {"key": "vKQi3bBA1y8", "site": "YouTube", "type": "Trailer", "official": true}
    ]
  },
  "release_dates": {
    "results": [
      {
        "iso_3166_1": "PL",
        "release_dates": [
          {"certification": ""},
          {"certification": "16"}
        ]
      },
      {
        "iso_3166_1": "US",
        "release_dates": [
          {"certification": "R"}
        ]
      }
    ]
  },
  "watch/providers": {
    "results": {
      "PL": {
        "link": "https://www.themoviedb.org/movie/603-the-matrix/watch?locale=PL",
        "flatrate": [
          {"provider_id": 119, "provider_name": "Amazon Prime Video", "logo_path": "/gMZd.png"}
        ],
        "rent": [
          {"provider_id": 2, "provider_name": "Apple TV", "logo_path": "/peUR.png"}
        ]
      }
    }
  },
  "recommendations": {
    "results": [
      {
        "id": 604,
        "title": "The Matrix Reloaded",
        "overview": "Neo and the rebel leaders estimate they have 72 hours.",
        "release_date": "2003-05-15",
        "poster_path": "/9TGHDvWrqKBzwDxDodHYXEmOE6J.jpg",
        "vote_average": 6.7,
        "genre_ids": [28, 878]
      }
    ]
  }
}
"""

private let announcedMovieDetailsJSON = """
{
  "id": 999,
  "tagline": "",
  "runtime": null,
  "credits": {
    "cast": [],
    "crew": []
  },
  "videos": {
    "results": []
  },
  "release_dates": {
    "results": []
  },
  "watch/providers": {
    "results": {}
  },
  "recommendations": {
    "results": []
  }
}
"""

private func makeMovieDetails(
    id: Int = 603,
    tagline: String = "",
    runtime: Int? = nil,
    cast: [CastMember] = [],
    crew: [CrewMember] = [],
    videos: [Video] = [],
    releaseDates: [CountryReleaseDates] = [],
    watchProviders: [String: CountryWatchProviders] = [:],
    recommendations: [Movie] = []
) -> MovieDetails {
    return MovieDetails(
        id: id,
        tagline: tagline,
        runtime: runtime,
        credits: Credits(cast: cast, crew: crew),
        videos: VideoList(results: videos),
        releaseDates: ReleaseDateList(results: releaseDates),
        watchProviders: WatchProviderList(results: watchProviders),
        recommendations: TMDBMoviePage(results: recommendations)
    )
}

@MainActor
struct MovieDetailsDecodingTests {
    @Test
    func decodesTaglineAndRuntime() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(details.id == 603)
        #expect(details.tagline == "Believe the unbelievable.")
        #expect(details.runtime == 136)
    }

    @Test
    func decodesCastWithAndWithoutPhoto() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(details.credits.cast.count == 2)
        #expect(details.credits.cast[0].profilePath == "/8RZL.jpg")
        #expect(details.credits.cast[1].profilePath == nil)
    }

    @Test
    func decodesWatchProvidersUnderSlashKey() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))
        let plProviders = try #require(details.watchProviders.results["PL"])

        #expect(plProviders.flatrate?.count == 1)
        #expect(plProviders.rent?.count == 1)
        #expect(plProviders.buy == nil)
    }

    @Test
    func decodesCountryCodeOfReleaseDates() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(details.releaseDates.results.first?.countryCode == "PL")
    }

    @Test
    func decodesRecommendationsAsMovies() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(details.recommendations.results.count == 1)
        #expect(details.recommendations.results[0].id == 604)
        #expect(details.recommendations.results[0].title == "The Matrix Reloaded")
    }

    @Test
    func decodesAnnouncedMovieWithoutRuntime() throws {
        let details = try decodeTMDBMovieDetails(Data(announcedMovieDetailsJSON.utf8))
        let plProviders = watchProviders(details, regionCode: "PL")

        #expect(details.runtime == nil)
        #expect(formattedRuntime(details) == "")
        #expect(hasWatchProviders(plProviders) == false)
    }
}

@MainActor
struct MovieDetailsTests {
    @Test
    func runtimeInHoursAndMinutes() {
        #expect(formattedRuntime(makeMovieDetails(runtime: 136)) == "2h 16m")
        #expect(formattedRuntime(makeMovieDetails(runtime: 120)) == "2h 0m")
    }

    @Test
    func runtimeUnderAnHourHasOnlyMinutes() {
        #expect(formattedRuntime(makeMovieDetails(runtime: 45)) == "45m")
    }

    @Test
    func runtimeIsEmptyWhenUnknown() {
        #expect(formattedRuntime(makeMovieDetails(runtime: nil)) == "")
        #expect(formattedRuntime(makeMovieDetails(runtime: 0)) == "")
    }

    @Test
    func directorsAreListedOnceEach() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(directorNames(details) == "Lana Wachowski, Lilly Wachowski")
    }

    @Test
    func directorsAreEmptyWithoutDirector() {
        let details = makeMovieDetails(
            crew: [CrewMember(id: 1, name: "Joel Silver", job: "Producer")]
        )

        #expect(directorNames(details) == "")
    }

    @Test
    func certificationSkipsEmptyOnes() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(ageCertification(details, regionCode: "PL") == "16")
        #expect(ageCertification(details, regionCode: "US") == "R")
    }

    @Test
    func certificationIsEmptyForOtherCountry() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(ageCertification(details, regionCode: "DE") == "")
    }

    @Test
    func officialTrailerWins() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(trailerKey(details) == "vKQi3bBA1y8")
    }

    @Test
    func unofficialTrailerWhenNoOfficial() {
        let details = makeMovieDetails(
            videos: [
                Video(key: "fan123", site: "YouTube", type: "Trailer", official: false),
                Video(key: "fan456", site: "YouTube", type: "Trailer", official: false)
            ]
        )

        #expect(trailerKey(details) == "fan123")
    }

    @Test
    func trailerOnOtherSiteIsSkipped() {
        let details = makeMovieDetails(
            videos: [
                Video(key: "vimeo123", site: "Vimeo", type: "Trailer", official: true)
            ]
        )

        #expect(trailerKey(details) == "")
        #expect(hasTrailer(details) == false)
    }

    @Test
    func trailerURLPointsToYouTube() {
        let details = makeMovieDetails(
            videos: [
                Video(key: "vKQi3bBA1y8", site: "YouTube", type: "Trailer", official: true)
            ]
        )

        #expect(trailerURL(details)?.absoluteString == "https://www.youtube.com/watch?v=vKQi3bBA1y8")
    }

    @Test
    func factsLineAddsRuntimeAndCertification() throws {
        let movie = Movie(
            id: 603,
            title: "The Matrix",
            overview: "",
            releaseDate: "1999-03-31",
            posterPath: nil,
            voteAverage: 8.2,
            genreIds: [28, 878]
        )
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(movieFactsLine(movie, details, regionCode: "PL") == "1999 · ★ 8.2 · 2h 16m · 16")
    }

    @Test
    func factsLineBeforeDetailsLoad() {
        let movie = Movie(
            id: 603,
            title: "The Matrix",
            overview: "",
            releaseDate: "1999-03-31",
            posterPath: nil,
            voteAverage: 8.2,
            genreIds: [28, 878]
        )

        #expect(movieFactsLine(movie, emptyMovieDetails, regionCode: "PL") == "1999 · ★ 8.2")
    }

    @Test
    func profileURLIsNilWithoutPhoto() {
        let withPhoto = CastMember(id: 1, name: "Keanu Reeves", character: "Neo", profilePath: "/8RZL.jpg")
        let withoutPhoto = CastMember(id: 2, name: "Extra", character: "Agent", profilePath: nil)

        #expect(profileURL(withPhoto)?.absoluteString == "https://image.tmdb.org/t/p/w185/8RZL.jpg")
        #expect(profileURL(withoutPhoto) == nil)
    }
}

private let testToday = Date(timeIntervalSince1970: 1_793_923_200) // 2026-11-06
private let releaseTypeDigital = 4

private func makeDetailsWithRelease(
    countryCode: String = "PL",
    releaseDate: String,
    type: Int
) -> MovieDetails {
    return MovieDetails(
        id: 1,
        tagline: "",
        runtime: 120,
        credits: Credits(cast: [], crew: []),
        videos: VideoList(results: []),
        releaseDates: ReleaseDateList(
            results: [
                CountryReleaseDates(
                    countryCode: countryCode,
                    releaseDates: [
                        ReleaseDate(
                            certification: "12",
                            releaseDate: releaseDate,
                            type: type
                        )
                    ]
                )
            ]
        ),
        watchProviders: WatchProviderList(results: [:]),
        recommendations: TMDBMoviePage(results: [])
    )
}

@MainActor
struct InCinemasTests {
    @Test
    func recentCinemaPremiereIsInCinemas() {
        let details = makeDetailsWithRelease(
            releaseDate: "2026-10-17T00:00:00.000Z",
            type: releaseTypeTheatrical
        )
        #expect(isInCinemas(details, regionCode: "PL", today: testToday) == true)
    }

    @Test
    func limitedReleaseCountsToo() {
        let details = makeDetailsWithRelease(
            releaseDate: "2026-10-17T00:00:00.000Z",
            type: releaseTypeTheatricalLimited
        )
        #expect(isInCinemas(details, regionCode: "PL", today: testToday) == true)
    }

    @Test
    func oldPremiereIsNotInCinemas() {
        let details = makeDetailsWithRelease(
            releaseDate: "2026-08-01T00:00:00.000Z",
            type: releaseTypeTheatrical
        )
        #expect(isInCinemas(details, regionCode: "PL", today: testToday) == false)
    }

    @Test
    func futurePremiereIsNotInCinemasYet() {
        let details = makeDetailsWithRelease(
            releaseDate: "2026-12-01T00:00:00.000Z",
            type: releaseTypeTheatrical
        )
        #expect(isInCinemas(details, regionCode: "PL", today: testToday) == false)
    }

    @Test
    func digitalReleaseIsNotCinema() {
        let details = makeDetailsWithRelease(
            releaseDate: "2026-10-17T00:00:00.000Z",
            type: releaseTypeDigital
        )
        #expect(isInCinemas(details, regionCode: "PL", today: testToday) == false)
    }

    @Test
    func premiereInAnotherCountryDoesNotCount() {
        let details = makeDetailsWithRelease(
            countryCode: "US",
            releaseDate: "2026-10-17T00:00:00.000Z",
            type: releaseTypeTheatrical
        )
        #expect(isInCinemas(details, regionCode: "PL", today: testToday) == false)
    }

    @Test
    func unreadableDateIsNotInCinemas() {
        let details = makeDetailsWithRelease(
            releaseDate: "not-a-date",
            type: releaseTypeTheatrical
        )
        #expect(daysSinceReleaseDay("not-a-date", today: testToday) == -1)
        #expect(isInCinemas(details, regionCode: "PL", today: testToday) == false)
    }
}
