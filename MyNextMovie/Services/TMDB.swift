import Foundation
import SwiftData

// MARK: - Constants

private let tmdbScheme = "https"
private let tmdbHost = "api.themoviedb.org"

private let popularPath = "/3/movie/popular"
private let searchPath = "/3/search/movie"
private let discoverPath = "/3/discover/movie"

private let apiKeyParam = "api_key"
private let queryParam = "query"
private let withGenresParam = "with_genres"

let httpStatusOK = 200
let httpStatusUnauthorized = 401

private let missingAPIKeyMessage = "Missing TMDB API key. Add it to Config/Secrets.xcconfig."

// MARK: - Types

nonisolated struct TMDBMoviePage: Decodable {
    let results: [Movie]
}

struct TMDBError: LocalizedError {
    let message: String

    var errorDescription: String? {
        return message
    }
}

// MARK: - URL Builders

func tmdbURL(path: String, parameters: [URLQueryItem], apiKey: String) -> URL? {
    var components = URLComponents()
    components.scheme = tmdbScheme
    components.host = tmdbHost
    components.path = path
    components.queryItems = [URLQueryItem(name: apiKeyParam, value: apiKey)] + parameters
    return components.url
}

func tmdbPopularURL(apiKey: String) -> URL? {
    return tmdbURL(path: popularPath, parameters: [], apiKey: apiKey)
}

func tmdbSearchURL(query: String, genreId: Int, apiKey: String) -> URL? {
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    if !trimmedQuery.isEmpty {
        return tmdbURL(
            path: searchPath,
            parameters: [URLQueryItem(name: queryParam, value: trimmedQuery)],
            apiKey: apiKey
        )
    } else {
        return tmdbURL(
            path: discoverPath,
            parameters: [URLQueryItem(name: withGenresParam, value: String(genreId))],
            apiKey: apiKey
        )
    }
}

private let movieDetailsPathPrefix = "/3/movie/"
private let appendToResponseParam = "append_to_response"
private let appendToResponseValue = "credits,videos,release_dates,watch/providers,recommendations"

func tmdbMovieDetailsURL(movieId: Int, apiKey: String) -> URL? {
    return tmdbURL(
        path: "\(movieDetailsPathPrefix)\(movieId)",
        parameters: [URLQueryItem(name: appendToResponseParam, value: appendToResponseValue)],
        apiKey: apiKey
    )
}

// MARK: - Decoding & Response Checking

func decodeTMDBMovies(_ data: Data) throws -> [Movie] {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let page = try decoder.decode(TMDBMoviePage.self, from: data)
    return page.results
}

func checkTMDBResponse(_ response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw TMDBError(message: "Invalid server response.")
    }
    if httpResponse.statusCode == httpStatusUnauthorized {
        throw TMDBError(message: "Invalid TMDB API key (HTTP 401).")
    }
    if httpResponse.statusCode != httpStatusOK {
        throw TMDBError(message: "TMDB request failed with status code \(httpResponse.statusCode).")
    }
}

// MARK: - Network Requests

private func fetchTMDBData(_ address: URL?) async throws -> Data {
    guard let url = address else {
        throw TMDBError(message: "Invalid TMDB URL.")
    }
    let (data, response) = try await URLSession.shared.data(from: url)
    try checkTMDBResponse(response)
    return data
}

func fetchPopularMovies() async throws -> [Movie] {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError(message: missingAPIKeyMessage)
    }
    let data = try await fetchTMDBData(tmdbPopularURL(apiKey: apiKey))
    return try decodeTMDBMovies(data)
}

func searchTMDBMovies(query: String, genreId: Int) async throws -> [Movie] {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError(message: missingAPIKeyMessage)
    }
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    let data = try await fetchTMDBData(tmdbSearchURL(query: trimmedQuery, genreId: genreId, apiKey: apiKey))
    let movies = try decodeTMDBMovies(data)
    
    if !trimmedQuery.isEmpty {
        return filterMovies(movies, query: "", genreId: genreId)
    }
    return movies
}

func decodeTMDBMovieDetails(_ data: Data) throws -> MovieDetails {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(MovieDetails.self, from: data)
}

func fetchMovieDetails(movieId: Int) async throws -> MovieDetails {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError(message: missingAPIKeyMessage)
    }
    let data = try await fetchTMDBData(tmdbMovieDetailsURL(movieId: movieId, apiKey: apiKey))
    return try decodeTMDBMovieDetails(data)
}

// MARK: - Cached Requests

private let popularCacheKey = "popular"
private let movieDetailsCacheKeyPrefix = "movie/"

func loadPopularMovies(cache: ModelContext) async throws -> [Movie] {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError(message: missingAPIKeyMessage)
    }
    let data = try await fetchWithCacheFallback(cache, key: popularCacheKey) {
        return try await fetchTMDBData(tmdbPopularURL(apiKey: apiKey))
    }
    return try decodeTMDBMovies(data)
}

func loadTMDBMovieDetails(movieId: Int, cache: ModelContext) async throws -> MovieDetails {
    let apiKey = tmdbAPIKey()
    guard !apiKey.isEmpty else {
        throw TMDBError(message: missingAPIKeyMessage)
    }
    let cacheKey = "\(movieDetailsCacheKeyPrefix)\(movieId)"
    let data = try await fetchWithCacheFallback(cache, key: cacheKey) {
        return try await fetchTMDBData(tmdbMovieDetailsURL(movieId: movieId, apiKey: apiKey))
    }
    return try decodeTMDBMovieDetails(data)
}
