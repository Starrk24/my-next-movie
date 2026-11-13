import Foundation
import Supabase

let minimumPasswordLength = 6
let testAccountEmail = "test@test.test"
let testAccountPassword = "test"

private let savedMoviesTable = "saved_movies"
private let idColumn = "id"
private let savedAtColumn = "saved_at"
private let userAndMovieConflictKey = "user_id,id"

private let missingSupabaseKeysMessage = "Missing Supabase keys. Add them to Config/Secrets.xcconfig."

struct SupabaseError: LocalizedError {
    let message: String

    var errorDescription: String? {
        return message
    }
}

private var sharedSupabaseClient: SupabaseClient?

private func requireSupabaseClient() throws -> SupabaseClient {
    if let existingClient = sharedSupabaseClient {
        return existingClient
    }
    let urlString = supabaseURL()
    let anonKey = supabaseAnonKey()
    guard
        !urlString.isEmpty,
        let url = URL(string: urlString),
        url.scheme != nil,
        url.host != nil,
        !anonKey.isEmpty
    else {
        throw SupabaseError(message: missingSupabaseKeysMessage)
    }
    let client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    sharedSupabaseClient = client
    return client
}

// MARK: - Task 2: Account Auth

@MainActor
func supabaseSignedInEmail() -> String {
    guard let client = try? requireSupabaseClient() else {
        return ""
    }
    return client.auth.currentUser?.email ?? ""
}

func signInToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let session = try await client.auth.signIn(email: email, password: password)
    return session.user.email ?? email
}

func signUpToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let response = try await client.auth.signUp(email: email, password: password)
    guard let session = response.session else {
        return ""
    }
    return session.user.email ?? email
}

func signOutOfSupabase() async throws {
    guard let client = try? requireSupabaseClient() else {
        return
    }
    try? await client.auth.signOut()
}

let supabaseAccountService = AccountService(
    signedInEmail: supabaseSignedInEmail,
    signIn: signInToSupabase,
    signUp: signUpToSupabase,
    signOut: signOutOfSupabase
)

// MARK: - Task 3: Saved Movies Cloud Table

nonisolated struct CloudSavedMovie: Codable, Equatable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: String
    let posterPath: String?
    let voteAverage: Double
    let genreIds: [Int]
    let savedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
        case savedAt = "saved_at"
    }
}

func fetchCloudSavedMovies() async throws -> [CloudSavedMovie] {
    let client = try requireSupabaseClient()
    let cloudMovies: [CloudSavedMovie] = try await client
        .from(savedMoviesTable)
        .select()
        .order(savedAtColumn, ascending: false)
        .execute()
        .value
    return cloudMovies
}

func uploadCloudSavedMovies(_ cloudMovies: [CloudSavedMovie]) async throws {
    guard !cloudMovies.isEmpty else {
        return
    }
    let client = try requireSupabaseClient()
    try await client
        .from(savedMoviesTable)
        .upsert(
            cloudMovies,
            onConflict: userAndMovieConflictKey,
            returning: .minimal,
            ignoreDuplicates: true
        )
        .execute()
}

func removeCloudSavedMovie(movieId: Int) async throws {
    let client = try requireSupabaseClient()
    try await client
        .from(savedMoviesTable)
        .delete(returning: .minimal)
        .eq(idColumn, value: movieId)
        .execute()
}

let supabaseSavedMoviesCloud = SavedMoviesCloud(
    fetchMovies: fetchCloudSavedMovies,
    uploadMovies: uploadCloudSavedMovies,
    removeMovie: removeCloudSavedMovie
)
