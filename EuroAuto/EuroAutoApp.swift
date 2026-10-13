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
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 1180, height: 780)
        #endif
    }
}

extension Color {
    static let euroGreen = Color(red: 0.17, green: 0.38, blue: 0.31)
    static let euroInk = Color(red: 0.12, green: 0.17, blue: 0.16)
    static let euroCanvas = Color(red: 0.96, green: 0.97, blue: 0.95)
    static let euroAmber = Color(red: 0.76, green: 0.50, blue: 0.20)
}
