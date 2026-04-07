//
//  ConfigurePhaseView.swift
//  BuneIOS
//
//  Created by techvvs001 on 4/6/26.
//

import SwiftUI

// MARK: - Configure Phase View

struct ConfigurePhaseView: View {
    @ObservedObject var viewModel: SessionBuilderViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configure Session")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(BuneColors.textPrimary)

                    Text("Set up transfer details and assignment")
                        .font(.subheadline)
                        .foregroundColor(BuneColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Section 1: Transporter
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transporter")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        GlassPickerRow(
                            label: "Select Transporter",
                            value: viewModel.transporters.first(where: { $0.id == viewModel.selectedTransporterId })?.name,
                            showPicker: true,
                            options: viewModel.transporters.map { ($0.id, $0.name) }
                        ) { selectedId in
                            if let id = selectedId as? Int {
                                viewModel.selectedTransporterId = id
                            }
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Section 2: Recipient
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recipient")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        GlassPickerRow(
                            label: "Select Recipient Facility",
                            value: viewModel.destinations.first(where: { $0.id == viewModel.selectedDestinationId })?.name,
                            showPicker: true,
                            options: viewModel.destinations.map { ($0.id, $0.name) }
                        ) { selectedId in
                            if let id = selectedId as? Int {
                                viewModel.selectedDestinationId = id
                            }
                        }

                        if let destination = viewModel.destinations.first(where: { $0.id == viewModel.selectedDestinationId }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Divider()
                                    .background(BuneColors.glassBorder)

                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.caption)
                                        .foregroundColor(BuneColors.textTertiary)
                                    Text("License: \(destination.license ?? "N/A")")
                                        .font(.caption2)
                                        .foregroundColor(BuneColors.textSecondary)
                                }

                                if let address = destination.address {
                                    HStack(spacing: 8) {
                                        Image(systemName: "mappin")
                                            .font(.caption)
                                            .foregroundColor(BuneColors.textTertiary)
                                        Text(address)
                                            .font(.caption2)
                                            .foregroundColor(BuneColors.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Section 3: Transfer Type
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transfer Type")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        GlassPickerRow(
                            label: "Select Transfer Type",
                            value: viewModel.selectedTransferType,
                            showPicker: true,
                            options: viewModel.transferTypes.map { ($0.name, $0.name) }
                        ) { selectedValue in
                            if let value = selectedValue as? String {
                                viewModel.selectedTransferType = value
                            }
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Section 4: Driver & Vehicle
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Driver & Vehicle")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        // Driver
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Driver")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)

                            GlassPickerRow(
                                label: "Select Driver",
                                value: viewModel.drivers.first(where: { $0.id == viewModel.selectedDriverId })?.name,
                                showPicker: true,
                                options: viewModel.drivers.map { ($0.id, $0.name) }
                            ) { selectedId in
                                if let id = selectedId as? Int {
                                    viewModel.selectedDriverId = id
                                }
                            }

                            if let driver = viewModel.drivers.first(where: { $0.id == viewModel.selectedDriverId }),
                               let license = driver.licenseNumber {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                        .foregroundColor(BuneColors.textTertiary)
                                    Text("License: \(license)")
                                        .font(.caption2)
                                        .foregroundColor(BuneColors.textSecondary)
                                }
                                .padding(.top, 4)
                            }
                        }

                        Divider()
                            .background(BuneColors.glassBorder)

                        // Vehicle
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Vehicle")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)

                            GlassPickerRow(
                                label: "Select Vehicle",
                                value: viewModel.vehicles.first(where: { $0.id == viewModel.selectedVehicleId })?.plate,
                                showPicker: true,
                                options: viewModel.vehicles.map { ($0.id, $0.plate) }
                            ) { selectedId in
                                if let id = selectedId as? Int {
                                    viewModel.selectedVehicleId = id
                                }
                            }

                            if let vehicle = viewModel.vehicles.first(where: { $0.id == viewModel.selectedVehicleId }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "car.fill")
                                        .font(.caption2)
                                        .foregroundColor(BuneColors.textTertiary)
                                    Text("\(vehicle.make ?? "Unknown") \(vehicle.model ?? "")")
                                        .font(.caption2)
                                        .foregroundColor(BuneColors.textSecondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Section 5: Route (Optional)
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Route (Optional)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        GlassPickerRow(
                            label: "Select Route",
                            value: viewModel.routes.first(where: { $0.id == viewModel.selectedRouteId })?.name,
                            showPicker: true,
                            options: viewModel.routes.map { ($0.id, $0.name) }
                        ) { selectedId in
                            if let id = selectedId as? Int {
                                viewModel.selectedRouteId = id
                            }
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Section 6: Schedule
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Schedule")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Estimated Departure")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)

                            DatePicker(
                                "",
                                selection: $viewModel.estimatedDeparture,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                            .preferredColorScheme(.dark)
                        }

                        Divider()
                            .background(BuneColors.glassBorder)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Estimated Arrival")
                                .font(.caption2)
                                .foregroundColor(BuneColors.textTertiary)

                            DatePicker(
                                "",
                                selection: $viewModel.estimatedArrival,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                            .preferredColorScheme(.dark)
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Section 7: Notes
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes (Optional)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BuneColors.textSecondary)

                        TextEditor(text: $viewModel.notes)
                            .font(.system(size: 14))
                            .foregroundColor(BuneColors.textPrimary)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(BuneColors.glassBorder, lineWidth: 1)
                                    )
                            )
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Navigation buttons
                HStack(spacing: 12) {
                    Button(action: { viewModel.goBackPhase() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BuneColors.glassFill)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(BuneColors.glassBorder, lineWidth: 1))
                    .foregroundColor(BuneColors.textPrimary)

                    Button(action: {
                        Task {
                            await viewModel.updateSessionConfig()
                            viewModel.advancePhase()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("Next: Review")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accentButton()
                    .opacity(viewModel.selectedDriverId != nil &&
                             viewModel.selectedVehicleId != nil &&
                             viewModel.selectedDestinationId != nil ? 1.0 : 0.5)
                    .disabled(viewModel.selectedDriverId == nil ||
                              viewModel.selectedVehicleId == nil ||
                              viewModel.selectedDestinationId == nil)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .task {
            await viewModel.loadReferenceData()
        }
    }
}

// MARK: - Glass Picker Row Component

struct GlassPickerRow<T>: View {
    let label: String
    let value: String?
    let showPicker: Bool
    let options: [(T, String)]
    let onSelect: (T) -> Void

    @State private var isPresentingPicker = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isPresentingPicker = true }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.caption2)
                            .foregroundColor(BuneColors.textTertiary)

                        Text(value ?? "Not Selected")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(value != nil ? BuneColors.textPrimary : BuneColors.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BuneColors.accentPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BuneColors.glassFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(BuneColors.glassBorder, lineWidth: 1)
                        )
                )
            }

            if isPresentingPicker {
                Divider()
                    .background(BuneColors.glassBorder)

                VStack(spacing: 8) {
                    SearchBar(text: $searchText)

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(0..<filteredOptions.count, id: \.self) { index in
                                Button(action: {
                                    onSelect(filteredOptions[index].0)
                                    isPresentingPicker = false
                                    searchText = ""
                                }) {
                                    HStack(spacing: 12) {
                                        Text(filteredOptions[index].1)
                                            .font(.system(size: 14))
                                            .foregroundColor(BuneColors.textPrimary)

                                        Spacer()

                                        if filteredOptions[index].1 == value {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(BuneColors.accentPrimary)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                }

                                if index < filteredOptions.count - 1 {
                                    Divider()
                                        .background(BuneColors.glassBorder)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding(12)
            }
        }
    }

    private var filteredOptions: [(T, String)] {
        if searchText.isEmpty {
            return options
        }
        return options.filter { $0.1.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Search Bar Component

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(BuneColors.textTertiary)

            TextField("Search...", text: $text)
                .font(.system(size: 14))
                .foregroundColor(BuneColors.textPrimary)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(BuneColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BuneColors.backgroundSecondary)
        )
    }
}

// MARK: - Preview

#Preview {
    let mockAuthService = AuthService()
    let mockAPIClient = TransportAPIClient(authService: mockAuthService)
    let viewModel = SessionBuilderViewModel(apiClient: mockAPIClient)

    ZStack {
        BuneColors.backgroundPrimary.ignoresSafeArea()

        ConfigurePhaseView(viewModel: viewModel)
    }
}
