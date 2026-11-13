import Foundation
import Testing
@testable import MyNextMovie

private let sampleMoviesJSON = """
{
  "page": 1,
  "results": [
    {
      "id": 603,
      "title": "The Matrix",
      "overview": "A hacker learns that the world is a simulation.",
      "release_date": "1999-03-31",
      "poster_path": "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
      "vote_average": 8.2,
      "genre_ids": [28, 878]
    },
    {
      "id": 604,
      "title": "The Matrix Reloaded",
      "overview": "Neo and the rebel leaders estimate they have 72 hours.",
      "release_date": "2003-05-15",
      "poster_path": null,
      "vote_average": 6.7,
      "genre_ids": [28, 878]
    }
  ]
}
"""

private let errorJSON = """
{
  "status_code": 7,
  "status_message": "Invalid API key."
}
"""

@MainActor
struct TMDBTests {
    @Test
    func decodesSnakeCaseKeys() throws {
        let data = Data(sampleMoviesJSON.utf8)
        let movies = try decodeTMDBMovies(data)

        #expect(movies.count == 2)
        #expect(movies[0].id == 603)
        #expect(movies[0].title == "The Matrix")
        #expect(movies[0].releaseDate == "1999-03-31")
        #expect(movies[0].posterPath == "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg")
        #expect(movies[0].voteAverage == 8.2)
        #expect(movies[0].genreIds == [28, 878])
    }

    @Test
    func decodesMissingPosterAsNil() throws {
        let data = Data(sampleMoviesJSON.utf8)
        let movies = try decodeTMDBMovies(data)

        #expect(movies[1].posterPath == nil)
    }

    @Test
    func decodingFailsForOtherJSON() {
        let data = Data(errorJSON.utf8)

        #expect(throws: DecodingError.self) {
            try decodeTMDBMovies(data)
        }
    }

    @Test
    func popularURLHasAPIKey() throws {
        let url = try #require(tmdbPopularURL(apiKey: "test-key"))

        #expect(url.absoluteString == "https://api.themoviedb.org/3/movie/popular?api_key=test-key")
    }

    @Test
    func searchWithTextUsesSearchEndpoint() throws {
        let searchURL = try #require(tmdbSearchURL(query: "matrix", genreId: 28, apiKey: "test-key"))
        let queryItems = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)?.queryItems

        #expect(searchURL.path() == "/3/search/movie")
        #expect(queryItems == [
            URLQueryItem(name: "api_key", value: "test-key"),
            URLQueryItem(name: "query", value: "matrix")
        ])
    }

    @Test
    func searchWithGenreOnlyUsesDiscoverEndpoint() throws {
        let searchURL = try #require(tmdbSearchURL(query: "   ", genreId: 16, apiKey: "test-key"))
        let queryItems = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)?.queryItems

        #expect(searchURL.path() == "/3/discover/movie")
        #expect(queryItems == [
            URLQueryItem(name: "api_key", value: "test-key"),
            URLQueryItem(name: "with_genres", value: "16")
        ])
    }

    @Test
    func searchTextIsPercentEncoded() throws {
        let searchURL = try #require(tmdbSearchURL(query: "pan tadeusz", genreId: noGenreId, apiKey: "test-key"))

        #expect(searchURL.absoluteString.contains("query=pan%20tadeusz"))
    }

    @Test
    func detailsURLAppendsEveryPart() throws {
        let detailsURL = try #require(tmdbMovieDetailsURL(movieId: 603, apiKey: "test-key"))
        let queryItems = URLComponents(url: detailsURL, resolvingAgainstBaseURL: false)?.queryItems

        #expect(detailsURL.path() == "/3/movie/603")
        #expect(queryItems == [
            URLQueryItem(name: "api_key", value: "test-key"),
            URLQueryItem(
                name: "append_to_response",
                value: "credits,videos,release_dates,watch/providers,recommendations"
            )
        ])
    }

    @Test
    func okResponsePasses() throws {
        let url = try #require(URL(string: "https://api.themoviedb.org"))
        let response = try #require(
            HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        )

        try checkTMDBResponse(response)
    }

    @Test
    func unauthorizedResponseMentionsAPIKey() throws {
        let url = try #require(URL(string: "https://api.themoviedb.org"))
        let response = try #require(
            HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)
        )

        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(response)
        }
        #expect(thrownError?.message.contains("API key") == true)
    }

    @Test
    func otherErrorResponseShowsStatus() throws {
        let url = try #require(URL(string: "https://api.themoviedb.org"))
        let response = try #require(
            HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)
        )

        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(response)
        }
        #expect(thrownError?.message.contains("404") == true)
    }
}
