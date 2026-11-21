//
//  CinemaMapView.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 14/11/2026.
//

import MapKit
import SwiftUI

enum CinemaMapPlacement {
    case tab
    case sheet
}

private let mapVerticalFraction: CGFloat = 0.45

struct CinemaMapView: View {
    @Bindable var viewModel: CinemaMapViewModel
    let findRoute: CinemaRouteFinder
    let placement: CinemaMapPlacement

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .region(wroclawMapRegion)
    @State private var selectedMarkerId: String?
    @State private var navigationPath: [Cinema] = []

    init(
        viewModel: CinemaMapViewModel,
        findRoute: @escaping CinemaRouteFinder,
        placement: CinemaMapPlacement
    ) {
        self.viewModel = viewModel
        self.findRoute = findRoute
        self.placement = placement
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                cinemaMap
                if viewModel.isLocationUnavailable {
                    locationUnavailableBanner
                }
                cinemaList
            }
            .navigationTitle("Cinemas")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Cinema.self) { cinema in
                CinemaDetailView(
                    viewModel: CinemaDetailViewModel(
                        cinema: cinema,
                        userLocation: viewModel.userLocation,
                        findRoute: findRoute
                    )
                )
            }
            .toolbar {
                if placement == .sheet {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.locateUserIfNeeded()
            }
        }
    }

    private var cinemaMap: some View {
        Map(position: $cameraPosition, selection: $selectedMarkerId) {
            UserAnnotation()
            ForEach(viewModel.cinemas) { cinema in
                Marker(
                    cinema.name,
                    systemImage: symbolNameCinema,
                    coordinate: cinemaCoordinate(cinema)
                )
                .tag(cinema.id)
            }
        }
        .mapStyle(
            .standard(
                emphasis: .muted,
                pointsOfInterest: .excludingAll
            )
        )
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .containerRelativeFrame(.vertical) { height, _ in
            height * mapVerticalFraction
        }
        .onChange(of: selectedMarkerId) { _, newValue in
            let newId = newValue ?? noCinemaSelected
            if viewModel.selectedCinemaId != newId {
                viewModel.selectedCinemaId = newId
            }
        }
    }

    private var locationUnavailableBanner: some View {
        HStack(spacing: spacingSmall) {
            Image(systemName: symbolNameLocationOff)
            Text("Turn on location to see distances and routes.")
            Spacer()
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, spacingLarge)
        .padding(.vertical, spacingSmall)
        .background(Color(.secondarySystemBackground))
    }

    private var cinemaList: some View {
        ScrollViewReader { proxy in
            List(viewModel.cinemas) { cinema in
                CinemaRow(
                    cinema: cinema,
                    isSelected: cinema.id == viewModel.selectedCinemaId,
                    selectCinema: {
                        selectCinemaFromRow(cinema)
                    },
                    openDetails: {
                        navigationPath.append(cinema)
                    }
                )
                .id(cinema.id)
            }
            .listStyle(.plain)
            .onChange(of: viewModel.selectedCinemaId) { _, newId in
                selectedMarkerId = newId.isEmpty ? nil : newId
                if !newId.isEmpty {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
    }

    private func selectCinemaFromRow(_ cinema: Cinema) {
        viewModel.toggleCinema(cinema.id)
        if viewModel.selectedCinemaId == cinema.id {
            withAnimation {
                cameraPosition = .region(viewModel.visibleRegion)
            }
        }
    }
}

private struct CinemaRow: View {
    let cinema: Cinema
    let isSelected: Bool
    let selectCinema: () -> Void
    let openDetails: () -> Void

    var body: some View {
        HStack(spacing: spacingMedium) {
            Button(action: selectCinema) {
                HStack {
                    VStack(alignment: .leading, spacing: spacingExtraSmall) {
                        Text(cinema.name)
                            .font(isSelected ? .headline.bold() : .headline)
                        Text(cinema.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    let distanceText = formattedDistance(cinema.distanceInMeters)
                    if !distanceText.isEmpty {
                        Text(distanceText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: openDetails) {
                Image(systemName: symbolNameDetails)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, spacingExtraSmall)
        .listRowBackground(
            isSelected ? Color.accentColor.opacity(0.12) : Color.clear
        )
    }
}

#Preview {
    CinemaMapView(
        viewModel: CinemaMapViewModel(
            cinemas: wroclawCinemas,
            findUserLocation: { fallbackUserLocation }
        ),
        findRoute: { _, _, _ in noRoute },
        placement: .tab
    )
}
