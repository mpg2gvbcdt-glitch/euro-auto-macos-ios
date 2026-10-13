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

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Nord Auto") {
                    ForEach(AppSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.symbol)
                            .tag(section as AppSection?)
                    }
                }
                Section("Данные") {
                    Label(AppSection.backup.rawValue, systemImage: AppSection.backup.symbol)
                        .tag(AppSection.backup as AppSection?)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Euro Auto")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240)
            #endif
        } detail: {
            switch selection ?? .overview {
            case .overview:
                DashboardView()
            case .vehicles:
                VehiclesView()
            case .customers:
                CustomersView()
            case .backup:
                BackupView()
            }
        }
        .background(Color.euroCanvas)
    }
}
