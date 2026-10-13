import SwiftData
import SwiftUI

private enum CalcusEngineChoice: String, CaseIterable, Identifiable {
    case petrol = "Бензиновый"
    case diesel = "Дизельный"
    case electric = "Электрический"
    case serialHybrid = "Последовательный гибрид"
    case parallelHybrid = "Параллельный гибрид"

    var id: Int { code }
    var code: Int {
        switch self {
        case .petrol: 1
        case .diesel: 2
        case .electric: 4
        case .serialHybrid: 5
        case .parallelHybrid: 6
        }
    }

    static func from(_ fuel: String) -> Self {
        switch fuel.lowercased() {
        case let value where value.contains("диз") || value.contains("diesel"): .diesel
        case let value where value.contains("элект") || value.contains("electric"): .electric
        case let value where value.contains("гибрид") || value.contains("hybrid"): .parallelHybrid
        default: .petrol
        }
    }
}

struct CalcusCustomsCalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    let vehicle: Vehicle

    @State private var owner = 2
    @State private var age = "0-3"
    @State private var engine: CalcusEngineChoice
    @State private var calculationYear = min(2030, max(2025, Calendar.current.component(.year, from: .now)))
    @State private var result: CalcusCustomsResult?
    @State private var errorMessage: String?
    @State private var isCalculating = false
    @State private var showingApplyConfirmation = false
    @State private var applyMessage: String?

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _engine = State(initialValue: CalcusEngineChoice.from(vehicle.engineType))
        let thisYear = Calendar.current.component(.year, from: .now)
        let ageYears = max(0, thisYear - (vehicle.year ?? thisYear))
        let initialAge = ageYears < 3 ? "0-3" : ageYears < 5 ? "3-5" : ageYears < 7 ? "5-7" : "7-0"
        _age = State(initialValue: initialAge)
        _owner = State(initialValue: vehicle.importerType == "Физическое лицо" ? 1 : 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Расчёт таможни · Calcus", systemImage: "function")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    CalcusSettingsView()
                } label: {
                    Label("Настройки", systemImage: "key.horizontal")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }

            Text("Calcus рассчитает таможенные платежи по характеристикам автомобиля. Каждый запуск расходует один оплаченный запрос и требует интернет.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 11) {
                GridRow {
                    Text("Импортер")
                    Picker("Импортер", selection: $owner) {
                        Text("Физлицо · для себя").tag(1)
                        Text("Юрлицо / ИП").tag(2)
                        Text("Физлицо · перепродажа").tag(3)
                    }
                    .labelsHidden()
                }
                GridRow {
                    Text("Возраст")
                    Picker("Возраст", selection: $age) {
                        ForEach(["0-3", "3-5", "5-7", "7-0"], id: \.self) { Text($0 + " лет").tag($0) }
                    }
                    .labelsHidden()
                }
                GridRow {
                    Text("Двигатель")
                    Picker("Тип двигателя", selection: $engine) {
                        ForEach(CalcusEngineChoice.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                }
                GridRow {
                    Text("Расчётный год")
                    Picker("Расчётный год", selection: $calculationYear) {
                        ForEach(2025...2030, id: \.self) { Text(String($0)).tag($0) }
                    }
                    .labelsHidden()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    Task { await calculate() }
                } label: {
                    HStack(spacing: 8) {
                        if isCalculating { ProgressView().controlSize(.small) }
                        Label(isCalculating ? "Считаю…" : "Рассчитать", systemImage: "equal.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.euroGreen)
                .disabled(isCalculating || !canCalculate)

                if !canCalculate {
                    Text(missingInputsMessage)
                        .font(.caption)
                        .foregroundStyle(Color.euroAmber)
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Color.euroAmber)
            }

            if let result {
                VStack(spacing: 0) {
                    resultRow("Сбор за оформление", result.sbor)
                    resultRow("Таможенная пошлина", result.tax)
                    resultRow("Утилизационный сбор", result.util)
                    resultRow("НДС", result.nds)
                    resultRow("Акциз", result.excise)
                    Divider().padding(.vertical, 6)
                    resultRow("Всего платежей", result.total, emphasis: true)
                    resultRow("Автомобиль + таможня", result.total2)
                }
                .padding(12)
                .background(Color.euroPanelRaised, in: RoundedRectangle(cornerRadius: 12))

                Button("Записать суммы в расходы автомобиля") {
                    showingApplyConfirmation = true
                }
                .buttonStyle(.bordered)
                .confirmationDialog("Записать расчёт Calcus?", isPresented: $showingApplyConfirmation, titleVisibility: .visible) {
                    Button("Заменить текущие суммы", role: .destructive, action: applyResult)
                    Button("Отмена", role: .cancel) {}
                } message: {
                    Text("Пошлина, сборы / НДС / акциз и утилизационный сбор в карточке автомобиля будут заменены результатом расчёта Calcus.")
                }
            }

            if let applyMessage {
                Text(applyMessage).font(.caption).foregroundStyle(Color.euroGreen)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            if let vehicleYear = vehicle.year { age = ageBand(for: vehicleYear, calculationYear: calculationYear) }
        }
        .onChange(of: calculationYear) { _, nextYear in
            if let vehicleYear = vehicle.year { age = ageBand(for: vehicleYear, calculationYear: nextYear) }
        }
    }

    private var canCalculate: Bool {
        vehicle.purchasePrice > 0 && vehicle.fxRate > 0 && vehicle.enginePowerHp != nil &&
        (engine == .electric || (vehicle.engineVolumeCc ?? 0) > 0)
    }

    private var missingInputsMessage: String {
        if vehicle.purchasePrice <= 0 { return "Укажите цену покупки." }
        if vehicle.enginePowerHp == nil { return "В каталоге нет мощности двигателя." }
        if engine != .electric && (vehicle.engineVolumeCc ?? 0) <= 0 { return "В каталоге нет объёма двигателя." }
        return "Проверьте курс покупки."
    }

    private func calculate() async {
        guard canCalculate else { return }
        isCalculating = true
        errorMessage = nil
        applyMessage = nil
        defer { isCalculating = false }

        let request = CalcusCustomsRequest(
            owner: owner,
            age: age,
            engine: engine.code,
            power: Double(vehicle.enginePowerHp ?? 0),
            power_unit: 1,
            value: vehicle.engineVolumeCc ?? 0,
            price: vehicle.purchasePrice * vehicle.fxRate,
            curr: "RUB",
            year: calculationYear
        )
        do {
            result = try await CalcusCustomsService.calculate(request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyResult() {
        guard let result else { return }
        vehicle.customsDuty = result.tax
        vehicle.customsFees = result.sbor + result.nds + result.excise
        vehicle.recyclingFee = result.util
        vehicle.updatedAt = .now
        do {
            try modelContext.save()
            WebsiteAutoSync.schedule(context: modelContext)
            applyMessage = "Расчёт записан в расходы автомобиля."
        } catch {
            applyMessage = "Не удалось сохранить расходы: \(error.localizedDescription)"
        }
    }

    private func resultRow(_ title: String, _ value: Double, emphasis: Bool = false) -> some View {
        HStack {
            Text(title).foregroundStyle(emphasis ? Color.euroInk : Color.secondary)
            Spacer()
            Text(value.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))))
                .fontWeight(emphasis ? .bold : .medium)
                .foregroundStyle(emphasis ? Color.euroGreen : Color.euroInk)
        }
        .font(emphasis ? .subheadline : .footnote)
        .padding(.vertical, 4)
    }

    private func ageBand(for vehicleYear: Int, calculationYear: Int) -> String {
        let age = max(0, calculationYear - vehicleYear)
        if age < 3 { return "0-3" }
        if age < 5 { return "3-5" }
        if age < 7 { return "5-7" }
        return "7-0"
    }
}
