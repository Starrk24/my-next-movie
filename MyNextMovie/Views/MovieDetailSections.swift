import SwiftUI

private let maxCastMembersCount = 15
private let castPhotoSize: CGFloat = 72
private let castItemWidth: CGFloat = 96
private let providerLogoSize: CGFloat = 40
private let providerLogoCornerRadius: CGFloat = 8
private let recommendationCardWidth: CGFloat = 150
private let castPlaceholderSymbol = "person.fill"
private let trailerSymbol = "play.fill"

struct MovieDetailSections: View {
    let details: MovieDetails

    var body: some View {
        VStack(alignment: .leading, spacing: spacingExtraLarge) {
            if let url = trailerURL(details) {
                TrailerButton(url: url)
            }
            if !details.credits.cast.isEmpty {
                CastSection(cast: Array(details.credits.cast.prefix(maxCastMembersCount)))
            }
            let countryProviders = watchProviders(details, regionCode: watchRegionCode)
            if hasWatchProviders(countryProviders) {
                WatchProvidersSection(providers: countryProviders)
            }
            if !details.recommendations.results.isEmpty {
                RecommendationsSection(movies: details.recommendations.results)
            }
        }
    }
}

private struct TrailerButton: View {
    let url: URL

    var body: some View {
        Link(destination: url) {
            Label("Watch Trailer", systemImage: trailerSymbol)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, spacingSmall)
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct CastSection: View {
    let cast: [CastMember]

    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            Text("Cast")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacingMedium) {
                    ForEach(cast) { member in
                        CastMemberItem(member: member)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}

private struct CastMemberItem: View {
    let member: CastMember

    var body: some View {
        VStack(spacing: spacingExtraSmall) {
            photo
                .frame(width: castPhotoSize, height: castPhotoSize)
                .clipShape(Circle())
            Text(member.name)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(member.character)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: castItemWidth)
    }

    @ViewBuilder
    private var photo: some View {
        if let url = profileURL(member) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholderView
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            Color.secondary.opacity(0.2)
            Image(systemName: castPlaceholderSymbol)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WatchProvidersSection: View {
    let providers: CountryWatchProviders

    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            Text("Where to Watch")
                .font(.headline)
            if let flatrate = providers.flatrate, !flatrate.isEmpty {
                ProviderGroupRow(title: "Stream", providers: flatrate)
            }
            if let rent = providers.rent, !rent.isEmpty {
                ProviderGroupRow(title: "Rent", providers: rent)
            }
            if let buy = providers.buy, !buy.isEmpty {
                ProviderGroupRow(title: "Buy", providers: buy)
            }
            Text("Streaming data from JustWatch")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProviderGroupRow: View {
    let title: String
    let providers: [WatchProvider]

    var body: some View {
        VStack(alignment: .leading, spacing: spacingSmall) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacingMedium) {
                    ForEach(providers) { provider in
                        ProviderItem(provider: provider)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}

private struct ProviderItem: View {
    let provider: WatchProvider

    var body: some View {
        HStack(spacing: spacingSmall) {
            logo
                .frame(width: providerLogoSize, height: providerLogoSize)
                .clipShape(RoundedRectangle(cornerRadius: providerLogoCornerRadius))
            Text(provider.providerName)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private var logo: some View {
        if let url = logoURL(provider) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
        } else {
            Color.secondary.opacity(0.2)
        }
    }
}

private struct RecommendationsSection: View {
    let movies: [Movie]

    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            Text("More Like This")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacingLarge) {
                    ForEach(movies) { movie in
                        RecommendationItem(movie: movie)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}

private struct RecommendationItem: View {
    let movie: Movie

    var body: some View {
        NavigationLink(value: movie) {
            MovieCardView(movie: movie)
                .frame(width: recommendationCardWidth)
        }
        .buttonStyle(.plain)
    }
}
