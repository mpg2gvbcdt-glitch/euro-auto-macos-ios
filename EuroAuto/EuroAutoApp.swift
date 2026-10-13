import SwiftData
import SwiftUI

@main
struct EuroAutoApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([Customer.self, Vehicle.self, VehicleDocument.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Не удалось открыть локальную базу Euro Auto: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .tint(Color.euroGreen)
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 1180, height: 780)
        #endif
    }
}

extension Color {
    static let euroGreen = Color(red: 0.43, green: 0.82, blue: 0.64)
    static let euroInk = Color(red: 0.91, green: 0.94, blue: 0.92)
    static let euroCanvas = Color(red: 0.055, green: 0.071, blue: 0.067)
    static let euroPanel = Color(red: 0.092, green: 0.115, blue: 0.107)
    static let euroPanelRaised = Color(red: 0.125, green: 0.153, blue: 0.141)
    static let euroLine = Color(red: 0.19, green: 0.24, blue: 0.22)
    static let euroAmber = Color(red: 0.94, green: 0.69, blue: 0.36)
}
