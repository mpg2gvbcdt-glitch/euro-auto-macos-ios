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
                Text("Nord Auto")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                ForEach([AppSection.overview, .vehicles, .customers]) { section in
                    SidebarButton(section: section, selection: $selection)
                }

                Text("Данные")
                    .font(.caption.weight(.semibold))
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
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .padding(.horizontal, 10)
                .background(isSelected ? Color.euroGreen.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9))
                .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}
