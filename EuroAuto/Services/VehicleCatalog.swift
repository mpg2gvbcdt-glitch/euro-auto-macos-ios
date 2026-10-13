import Foundation
import Observation

struct CatalogMake: Decodable, Identifiable {
    let make: String
    let models: [CatalogModel]
    var id: String { make }
}

struct CatalogModel: Decodable, Identifiable {
    let n: String
    let generations: [CatalogGeneration]
    var id: String { n }
}

struct CatalogGeneration: Decodable, Identifiable {
    let n: String
    let from: Int?
    let to: Int?
    let body: String?
    let engines: [CatalogEngine]
    var id: String { n }
}

struct CatalogEngine: Decodable, Identifiable {
    let n: String
    let f: String?
    let cy: Int?
    let cc: Int?
    let hp: Int?
    let dr: String?
    let tr: String?
    let l: Int?
    let w: Int?
    let h: Int?
    let wb: Int?
    let kg: Int?
    var id: String { n }

    var localizedFuel: String {
        switch (f ?? "").lowercased() {
        case "gasoline", "petrol": "Бензин"
        case "diesel": "Дизель"
        case "electric": "Электро"
        case "hybrid": "Гибрид"
        default: f ?? ""
        }
    }

    var localizedDrive: String {
        switch (dr ?? "").lowercased() {
        case "front wheel drive": "Передний"
        case "rear wheel drive": "Задний"
        case "all wheel drive", "four wheel drive": "Полный"
        default: dr ?? ""
        }
    }
}

@MainActor
@Observable
final class VehicleCatalogStore {
    static let shared = VehicleCatalogStore()

    private(set) var makes: [CatalogMake] = []
    private(set) var loadError: String?

    private init() {
        guard let url = Bundle.main.url(forResource: "vehicle-catalog", withExtension: "json") else {
            loadError = "Не найден локальный каталог автомобилей."
            return
        }
        do {
            makes = try JSONDecoder().decode([CatalogMake].self, from: Data(contentsOf: url))
                .sorted { $0.make.localizedStandardCompare($1.make) == .orderedAscending }
        } catch {
            loadError = "Не удалось прочитать каталог: \(error.localizedDescription)"
        }
    }

    func models(for make: String) -> [CatalogModel] {
        makes.first(where: { $0.make == make })?.models ?? []
    }

    func generations(for make: String, model: String) -> [CatalogGeneration] {
        models(for: make).first(where: { $0.n == model })?.generations ?? []
    }

    func engines(for make: String, model: String, generation: String) -> [CatalogEngine] {
        generations(for: make, model: model).first(where: { $0.n == generation })?.engines ?? []
    }
}
