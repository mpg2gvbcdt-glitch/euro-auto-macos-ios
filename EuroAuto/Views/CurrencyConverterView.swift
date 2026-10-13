import SwiftUI

struct CurrencyConverterView: View {
    private let currencies = ["RUB", "EUR", "USD", "GBP", "CHF", "SEK", "NOK", "DKK", "PLN"]

    @State private var amount = 1.0
    @State private var sourceCurrency = "EUR"
    @State private var targetCurrency = "RUB"
    @State private var selectedDate = Date.now
    @State private var snapshot = CBRCurrencyRatesService.cachedSnapshot()
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var exchangeRate: Double? {
        guard let source = snapshot?.ratesToRuble[sourceCurrency],
              let target = snapshot?.ratesToRuble[targetCurrency], target > 0 else { return nil }
        return source / target
    }

    private var convertedAmount: Double? {
        guard let exchangeRate else { return nil }
        return amount * exchangeRate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("ВАЛЮТНЫЙ ИНСТРУМЕНТ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.euroGreen)
                    Text("Конвертер валют")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.euroInk)
                    Text("Официальные курсы Банка России")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Справочный курс для расчётов; курс обмена банка может отличаться.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                GroupBox("Конвертация") {
                    VStack(alignment: .leading, spacing: 16) {
                        DatePicker("Дата курса", selection: $selectedDate, displayedComponents: .date)
                        TextField("Сумма", value: $amount, format: .number.precision(.fractionLength(0...2)))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 12) {
                            currencyPicker("Из", selection: $sourceCurrency)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(Color.euroGreen)
                            currencyPicker("В", selection: $targetCurrency)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 5) {
                            Text("РЕЗУЛЬТАТ")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                            Text(resultText)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.euroGreen)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                            if let exchangeRate {
                                Text("1 \(sourceCurrency) = \(exchangeRate.formatted(.number.precision(.fractionLength(2...4)))) \(targetCurrency)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(action: { Task { await refreshRates() } }) {
                            HStack {
                                if isLoading { ProgressView().controlSize(.small) }
                                Label(isLoading ? "Загружаю курс…" : "Обновить курс ЦБ", systemImage: "arrow.clockwise")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.euroGreen)
                        .disabled(isLoading)
                    }
                }

                GroupBox("Курсы к рублю") {
                    VStack(spacing: 0) {
                        if let snapshot {
                            ForEach(Array(currencies.dropFirst()), id: \.self) { code in
                                HStack {
                                    Text("1 \(code)")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(rateText(for: code, in: snapshot))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(Color.euroInk)
                                    Text("₽")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 9)
                                Divider()
                            }
                            Text("Курс ЦБ на \(snapshot.officialDate.formatted(date: .numeric, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 12)
                        } else {
                            ContentUnavailableView("Курсы ещё не загружены", systemImage: "dollarsign.arrow.circlepath", description: Text("Подключитесь к интернету и обновите курсы Банка России."))
                                .frame(minHeight: 140)
                        }
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "wifi.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(Color.euroAmber)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color.euroCanvas)
        .groupBoxStyle(EuroAutoGroupBoxStyle())
        .navigationTitle("Конвертер валют")
        .task {
            await refreshRates()
        }
    }

    private var resultText: String {
        guard let convertedAmount else { return "— \(targetCurrency)" }
        return convertedAmount.formatted(.number.precision(.fractionLength(2...2))) + " " + targetCurrency
    }

    private func currencyPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(currencies, id: \.self) { Text($0).tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
    }

    private func rateText(for code: String, in snapshot: CBRCurrencyRatesSnapshot) -> String {
        guard let rate = snapshot.ratesToRuble[code] else { return "—" }
        return rate.formatted(.number.precision(.fractionLength(2...4)))
    }

    @MainActor
    private func refreshRates() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            snapshot = try await CBRCurrencyRatesService.fetchRates(for: selectedDate)
        } catch {
            snapshot = CBRCurrencyRatesService.cachedSnapshot() ?? snapshot
            errorMessage = snapshot == nil
                ? "Не удалось загрузить курсы: \(error.localizedDescription)"
                : "Нет соединения. Показан последний сохранённый курс ЦБ."
        }
    }
}
