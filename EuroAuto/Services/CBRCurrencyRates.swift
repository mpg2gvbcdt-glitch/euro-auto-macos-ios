import Foundation

struct CBRCurrencyRatesSnapshot: Codable {
    let officialDate: Date
    let fetchedAt: Date
    let ratesToRuble: [String: Double]

    static let cacheKey = "nord-auto.cbr-rates.v1"
}

enum CBRCurrencyRatesService {
    static func fetchRates(for date: Date) async throws -> CBRCurrencyRatesSnapshot {
        var components = URLComponents(string: "https://www.cbr.ru/scripts/XML_daily.asp")
        components?.queryItems = [URLQueryItem(name: "date_req", value: requestDate.string(from: date))]
        guard let url = components?.url else { throw CBRCurrencyRatesError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw CBRCurrencyRatesError.requestFailed
        }

        let parser = CBRCurrencyXMLParser(data: data)
        let parsed = try parser.parse()
        let snapshot = CBRCurrencyRatesSnapshot(
            officialDate: parsed.date,
            fetchedAt: .now,
            ratesToRuble: parsed.rates
        )
        if let cachedData = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(cachedData, forKey: CBRCurrencyRatesSnapshot.cacheKey)
        }
        return snapshot
    }

    static func cachedSnapshot() -> CBRCurrencyRatesSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: CBRCurrencyRatesSnapshot.cacheKey) else { return nil }
        return try? JSONDecoder().decode(CBRCurrencyRatesSnapshot.self, from: data)
    }

    private static let requestDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Moscow")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
}

private enum CBRCurrencyRatesError: LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Не удалось подготовить запрос к Банку России."
        case .requestFailed: "Банк России не вернул курсы валют."
        case .invalidResponse: "Не удалось прочитать ответ Банка России."
        }
    }
}

private final class CBRCurrencyXMLParser: NSObject, XMLParserDelegate {
    private let xmlParser: XMLParser
    private var currentElement = ""
    private var isReadingCurrency = false
    private var fieldText: [String: String] = [:]
    private var dateText = ""
    private var rates: [String: Double] = ["RUB": 1]

    init(data: Data) {
        xmlParser = XMLParser(data: data)
        super.init()
        xmlParser.delegate = self
    }

    func parse() throws -> (date: Date, rates: [String: Double]) {
        guard xmlParser.parse(), let officialDate = Self.dateParser.date(from: dateText), rates.count > 1 else {
            throw xmlParser.parserError ?? CBRCurrencyRatesError.invalidResponse
        }
        return (officialDate, rates)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "ValCurs" {
            dateText = attributeDict["Date"] ?? ""
        } else if elementName == "Valute" {
            isReadingCurrency = true
            fieldText = [:]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isReadingCurrency {
            fieldText[currentElement, default: ""].append(string)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Valute", isReadingCurrency {
            let code = fieldText["CharCode"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let nominal = Self.number(fieldText["Nominal"] ?? "") ?? 0
            let value = Self.number(fieldText["Value"] ?? "") ?? 0
            if !code.isEmpty, nominal > 0, value > 0 {
                rates[code] = value / nominal
            }
            isReadingCurrency = false
            fieldText = [:]
        }
        currentElement = ""
    }

    private static func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }

    private static let dateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Moscow")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}
