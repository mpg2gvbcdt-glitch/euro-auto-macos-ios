import Foundation

struct CalcusCustomsRequest: Encodable {
    let owner: Int
    let age: String
    let engine: Int
    let power: Double
    let power_unit: Int
    let value: Int
    let price: Double
    let curr: String
    let year: Int
}

struct CalcusCustomsResult: Decodable {
    let sbor: Double
    let tax: Double
    let util: Double
    let nds: Double
    let excise: Double
    let total: Double
    let total2: Double

    var totalCalculatedCharges: Double { sbor + tax + util + nds + excise }
}

enum CalcusCustomsService {
    static func calculate(_ input: CalcusCustomsRequest) async throws -> CalcusCustomsResult {
        let credentials: CalcusKeyStore.Credentials
        do {
            credentials = try CalcusKeyStore.readCredentials()
        } catch {
            throw CalcusError.credentialsMissing
        }

        guard let url = URL(string: "https://calcus.ru/api/v1/Customs") else { throw CalcusError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(credentials.clientID, forHTTPHeaderField: "Api-Client-Id")
        request.setValue(credentials.apiKey, forHTTPHeaderField: "Api-Key")
        request.httpBody = try JSONEncoder().encode(input)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw CalcusError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CalcusError.serverRejected(httpResponse.statusCode)
        }
        let result = try JSONDecoder().decode(CalcusCustomsResult.self, from: data)
        guard [result.sbor, result.tax, result.util, result.nds, result.excise, result.total, result.total2].allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw CalcusError.invalidResponse
        }
        return result
    }

    enum CalcusError: LocalizedError {
        case credentialsMissing
        case invalidURL
        case invalidResponse
        case serverRejected(Int)

        var errorDescription: String? {
            switch self {
            case .credentialsMissing:
                "Сначала сохраните ID клиента и API-ключ в разделе «Настройки Calcus» на этом устройстве."
            case .invalidURL:
                "Не удалось подготовить запрос Calcus."
            case .invalidResponse:
                "Calcus вернул ответ, который приложение не смогло прочитать."
            case .serverRejected(let status):
                switch status {
                case 400: "Calcus не принял параметры расчёта. Проверьте характеристики автомобиля и валюту."
                case 401, 403: "Calcus отклонил доступ. Проверьте ID клиента и API-ключ в настройках."
                case 429: "Calcus временно ограничил число запросов. Попробуйте позже."
                default: "Сервис Calcus временно недоступен (ошибка \(status))."
                }
            }
        }
    }
}
