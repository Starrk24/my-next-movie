//
//  CinemaDetailView.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 14/11/2026.
//

import MapKit
import SwiftUI

private let detailMapHeight: CGFloat = 220
private let lookAroundHeight: CGFloat = 200
private let routeLineWidth: CGFloat = 5

struct CinemaDetailView: View {
    @Bindable var viewModel: CinemaDetailViewModel
    @State private var lookAroundScene: MKLookAroundScene?

    var body: some View {
        List {
            mapSection
            addressSection
            wayThereSection
            linksSection
            if let lookAroundScene {
                Section("Look Around") {
                    LookAroundPreview(initialScene: lookAroundScene)
                        .frame(height: lookAroundHeight)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .navigationTitle(viewModel.cinema.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.travelMode) {
            await viewModel.loadRoute()
        }
        .task {
            lookAroundScene = await findLookAroundScene(viewModel.cinema)
        }
    }

    private var mapSection: some View {
        Section {
            Map {
                UserAnnotation()
                Marker(
                    viewModel.cinema.name,
                    systemImage: symbolNameCinema,
                    coordinate: cinemaCoordinate(viewModel.cinema)
                )
                if viewModel.routeState == .loaded {
                    MapPolyline(viewModel.route.line)
                        .stroke(.tint, lineWidth: routeLineWidth)
                }
            }
            .mapStyle(
                .standard(
                    emphasis: .muted,
                    pointsOfInterest: .excludingAll
                )
            )
            .frame(height: detailMapHeight)
            .listRowInsets(EdgeInsets())
        }
    }

    private var addressSection: some View {
        Section {
            if !viewModel.cinema.address.isEmpty {
                Text(viewModel.cinema.address)
            }
            let distanceText = formattedDistance(viewModel.cinema.distanceInMeters)
            if !distanceText.isEmpty {
                LabeledContent("Distance", value: distanceText)
            }
        }
    }

    private var wayThereSection: some View {
        Section("Way There") {
            Picker("Travel Mode", selection: $viewModel.travelMode) {
                Label("Walk", systemImage: symbolNameWalking)
                    .tag(TravelMode.walking)
                Label("Drive", systemImage: symbolNameDriving)
                    .tag(TravelMode.driving)
            }
            .pickerStyle(.segmented)

            routeStatusRow
        }
    }

    @ViewBuilder
    private var routeStatusRow: some View {
        if !viewModel.canFindRoute {
            Label("Turn on location to see the route.", systemImage: symbolNameLocationOff)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            switch viewModel.routeState {
            case .idle, .loading:
                HStack(spacing: spacingMedium) {
                    ProgressView()
                    Text("Finding route...")
                        .foregroundStyle(.secondary)
                }
            case .loaded:
                Label(
                    routeSummary(viewModel.route),
                    systemImage: viewModel.travelMode == .walking
                        ? symbolNameWalking
                        : symbolNameDriving
                )
            case .failed:
                Text(viewModel.errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var linksSection: some View {
        Section {
            Button {
                openCinemaInMaps(viewModel.cinema, travelMode: viewModel.travelMode)
            } label: {
                Label("Directions in Maps", systemImage: symbolNameDirections)
            }

            if let phoneLink = phoneURL(viewModel.cinema) {
                Link(destination: phoneLink) {
                    Label(viewModel.cinema.phoneNumber, systemImage: symbolNamePhone)
                }
            }

            if let webLink = websiteURL(viewModel.cinema) {
                Link(destination: webLink) {
                    Label(viewModel.cinema.website, systemImage: symbolNameWebsite)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CinemaDetailView(
            viewModel: CinemaDetailViewModel(
                cinema: wroclawCinemas[0],
                userLocation: fallbackUserLocation,
                findRoute: { _, _, _ in noRoute }
            )
        )
    }
}
