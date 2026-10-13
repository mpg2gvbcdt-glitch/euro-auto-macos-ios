import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Обзор"
    case vehicles = "Автомобили"
    case customers = "Заказчики"
    case backup = "Перенос данных"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .vehicles: "car.side.fill"
        case .customers: "person.2.fill"
        case .backup: "externaldrive.fill"
        }
    }
}

struct ContentView: View {
    @State private var selection: AppSection? = .overview
    @State private var showingNewVehicle = false

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 11) {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.euroGreen)
                        .frame(width: 38, height: 38)
                        .background(Color.euroGreen.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NORD AUTO").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(1.1)
                        Text("УЧЁТ АВТОМОБИЛЕЙ").font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(Color.euroInk)
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 18)

                ForEach([AppSection.overview, .vehicles, .customers]) { section in
                    SidebarButton(section: section, selection: $selection)
                }

                Text("СИСТЕМА")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 14)

                SidebarButton(section: .backup, selection: $selection)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .navigationTitle("Euro Auto")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240)
            #endif
        } detail: {
            NavigationStack {
                Group {
                    switch selection ?? .overview {
                    case .overview:
                        DashboardView(onAddVehicle: {
                            selection = .vehicles
                            showingNewVehicle = true
                        })
                    case .vehicles:
                        VehiclesView(showingNewVehicle: $showingNewVehicle)
                    case .customers:
                        CustomersView()
                    case .backup:
                        BackupView()
                    }
                }
            }
        }
        .background(Color.euroCanvas)
    }
}

private struct SidebarButton: View {
    let section: AppSection
    @Binding var selection: AppSection?

    private var isSelected: Bool { selection == section }

    var body: some View {
        Button {
            selection = section
        } label: {
            Label(section.rawValue, systemImage: section.symbol)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.euroGreen : Color.euroInk)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.euroGreen.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .leading) {
                    if isSelected { Capsule().fill(Color.euroGreen).frame(width: 3, height: 20).padding(.leading, 1) }
                }
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
