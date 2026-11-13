import Foundation

// MARK: - Models

nonisolated struct MovieDetails: Decodable {
    let id: Int
    let tagline: String
    let runtime: Int?
    let credits: Credits
    let videos: VideoList
    let releaseDates: ReleaseDateList
    let watchProviders: WatchProviderList
    let recommendations: TMDBMoviePage

    enum CodingKeys: String, CodingKey {
        case id
        case tagline
        case runtime
        case credits
        case videos
        case releaseDates
        case watchProviders = "watch/providers"
        case recommendations
    }
}

nonisolated struct Credits: Decodable {
    let cast: [CastMember]
    let crew: [CrewMember]
}

nonisolated struct CastMember: Decodable, Identifiable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?
}

nonisolated struct CrewMember: Decodable {
    let id: Int
    let name: String
    let job: String
}

nonisolated struct VideoList: Decodable {
    let results: [Video]
}

nonisolated struct Video: Decodable {
    let key: String
    let site: String
    let type: String
    let official: Bool
}

nonisolated struct ReleaseDateList: Decodable {
    let results: [CountryReleaseDates]
}

nonisolated struct CountryReleaseDates: Decodable {
    let countryCode: String
    let releaseDates: [ReleaseDate]

    enum CodingKeys: String, CodingKey {
        case countryCode = "iso31661"
        case releaseDates
    }
}

nonisolated struct ReleaseDate: Decodable {
    let certification: String
}

nonisolated struct WatchProviderList: Decodable {
    let results: [String: CountryWatchProviders]
}

nonisolated struct CountryWatchProviders: Decodable {
    let link: String
    let flatrate: [WatchProvider]?
    let rent: [WatchProvider]?
    let buy: [WatchProvider]?
}

nonisolated struct WatchProvider: Decodable, Identifiable {
    let providerId: Int
    let providerName: String
    let logoPath: String?

    var id: Int {
        return providerId
    }
}

// MARK: - Constants

let emptyMovieDetails = MovieDetails(
    id: 0,
    tagline: "",
    runtime: nil,
    credits: Credits(cast: [], crew: []),
    videos: VideoList(results: []),
    releaseDates: ReleaseDateList(results: []),
    watchProviders: WatchProviderList(results: [:]),
    recommendations: TMDBMoviePage(results: [])
)

let noWatchProviders = CountryWatchProviders(
    link: "",
    flatrate: nil,
    rent: nil,
    buy: nil
)

let watchRegionCode = Locale.current.region?.identifier ?? "PL"

private let directorJob = "Director"
private let youtubeSite = "YouTube"
private let trailerType = "Trailer"
private let youtubeWatchBaseURL = "https://www.youtube.com/watch?v="
private let profileBaseURL = "https://image.tmdb.org/t/p/w185"
private let logoBaseURL = "https://image.tmdb.org/t/p/w92"
private let factsSeparator = " · "
private let minutesPerHour = 60

// MARK: - Functions

func formattedRuntime(_ details: MovieDetails) -> String {
    guard let runtime = details.runtime, runtime > 0 else {
        return ""
    }
    let hours = runtime / minutesPerHour
    let minutes = runtime % minutesPerHour
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}

func directorNames(_ details: MovieDetails) -> String {
    var directors: [String] = []
    for member in details.credits.crew {
        if member.job == directorJob && !directors.contains(member.name) {
            directors.append(member.name)
        }
    }
    return directors.joined(separator: ", ")
}

func ageCertification(_ details: MovieDetails, regionCode: String) -> String {
    for country in details.releaseDates.results {
        if country.countryCode == regionCode {
            for release in country.releaseDates {
                if !release.certification.isEmpty {
                    return release.certification
                }
            }
        }
    }
    return ""
}

func trailerKey(_ details: MovieDetails) -> String {
    var unofficialKey = ""
    for video in details.videos.results {
        if video.site == youtubeSite && video.type == trailerType {
            if video.official {
                return video.key
            }
            if unofficialKey.isEmpty {
                unofficialKey = video.key
            }
        }
    }
    return unofficialKey
}

func trailerURL(_ details: MovieDetails) -> URL? {
    let key = trailerKey(details)
    guard !key.isEmpty else {
        return nil
    }
    return URL(string: "\(youtubeWatchBaseURL)\(key)")
}

func hasTrailer(_ details: MovieDetails) -> Bool {
    return !trailerKey(details).isEmpty
}

func movieFactsLine(_ movie: Movie, _ details: MovieDetails, regionCode: String) -> String {
    var parts = [yearAndRating(movie)]
    let runtimeText = formattedRuntime(details)
    if !runtimeText.isEmpty {
        parts.append(runtimeText)
    }
    let certification = ageCertification(details, regionCode: regionCode)
    if !certification.isEmpty {
        parts.append(certification)
    }
    return parts.joined(separator: factsSeparator)
}

func watchProviders(_ details: MovieDetails, regionCode: String) -> CountryWatchProviders {
    return details.watchProviders.results[regionCode] ?? noWatchProviders
}

func hasWatchProviders(_ countryProviders: CountryWatchProviders) -> Bool {
    let hasFlatrate = !(countryProviders.flatrate ?? []).isEmpty
    let hasRent = !(countryProviders.rent ?? []).isEmpty
    let hasBuy = !(countryProviders.buy ?? []).isEmpty
    return hasFlatrate || hasRent || hasBuy
}

func profileURL(_ castMember: CastMember) -> URL? {
    guard let path = castMember.profilePath else {
        return nil
    }
    return URL(string: "\(profileBaseURL)\(path)")
}

func logoURL(_ provider: WatchProvider) -> URL? {
    guard let path = provider.logoPath else {
        return nil
    }
    return URL(string: "\(logoBaseURL)\(path)")
}
