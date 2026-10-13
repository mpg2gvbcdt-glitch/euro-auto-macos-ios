import SwiftData
import SwiftUI

private enum CatalogField: String, Identifiable {
    case make, model, generation, year, engine
    var id: String { rawValue }
    var title: String {
        switch self {
        case .make: "Марка"
        case .model: "Модель"
        case .generation: "Поколение"
        case .year: "Год выпуска"
        case .engine: "Двигатель"
        }
    }
    var subtitle: String {
        switch self {
        case .make: "Выберите производителя автомобиля"
        case .model: "Модели выбранной марки"
        case .generation: "Поколение и обозначение кузова"
        case .year: "Год выпуска выбранного поколения"
        case .engine: "Двигатели, доступные для выбранного года"
        }
    }
    var symbol: String {
        switch self {
        case .make: "car.side.fill"
        case .model: "car.side"
        case .generation: "rectangle.3.group"
        case .year: "calendar"
        case .engine: "gearshape.fill"
        }
    }
}

struct VehicleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Customer.name) private var customers: [Customer]
    @Bindable var vehicle: Vehicle
    let isNew: Bool
    @State private var catalogField: CatalogField?
    @State private var saveError: String?
    @State private var isLoadingCBRRate = false
    @State private var cbrRateMessage: String?
    @State private var cbrRateMessageIsError = false

    private let catalog = VehicleCatalogStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Автомобиль") {
                    #if os(iOS)
                    TextField("VIN", text: $vehicle.vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    #else
                    TextField("VIN", text: $vehicle.vin)
                        .autocorrectionDisabled()
                    #endif
                    catalogButton(.make, value: vehicle.make, enabled: true)
                    catalogButton(.model, value: vehicle.model, enabled: !vehicle.make.isEmpty)
                    catalogButton(.generation, value: vehicle.generation, enabled: !vehicle.model.isEmpty)
                    catalogButton(.engine, value: vehicle.engine, enabled: !vehicle.generation.isEmpty)
                    Picker("Тип ввоза", selection: $vehicle.importType) {
                        Text("На склад").tag("На склад")
                        Text("Под заказ").tag("Под заказ")
                    }
                    if vehicle.importType == "Под заказ" {
                        Picker("Заказчик", selection: customerSelection) {
                            Text("Не выбран").tag("")
                            ForEach(customers) { customer in Text("\(customer.code) · \(customer.name)").tag(customer.id.uuidString) }
                        }
                    }
                    Picker("Статус", selection: $vehicle.vehicleStatus) {
                        ForEach(["В пути", "На складе", "Оформление", "Готов к выдаче", "Продан"], id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Страна отправления", text: $vehicle.originCountry)
                    TextField("Местонахождение", text: $vehicle.location)
                    Picker("Импортер", selection: $vehicle.importerType) {
                        ForEach(["Юрлицо / ИП", "Физическое лицо"], id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Маршрут", selection: $vehicle.importRoute) {
                        ForEach(["Напрямую в Россию", "Через третью страну"], id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Характеристики из каталога") {
                    if selectedGeneration != nil {
                        catalogButton(.year, value: vehicle.year.map(String.init) ?? "", enabled: true)
                    } else {
                        LabeledContent("Год выпуска", value: vehicle.year.map(String.init) ?? "—")
                    }
                    LabeledContent("Двигатель", value: vehicle.engineVolumeCc.map { "\($0) см³" } ?? "—")
                    LabeledContent("Мощность", value: vehicle.enginePowerHp.map { "\($0) л.с." } ?? "—")
                    LabeledContent("Цилиндры", value: vehicle.engineCylinders.map(String.init) ?? "—")
                    LabeledContent("Топливо", value: vehicle.engineType.isEmpty ? "—" : vehicle.engineType)
                    LabeledContent("Привод", value: vehicle.driveType.isEmpty ? "—" : vehicle.driveType)
                    LabeledContent("Коробка", value: vehicle.transmission.isEmpty ? "—" : vehicle.transmission)
                    LabeledContent("Габариты", value: dimensions)
                    LabeledContent("Масса", value: vehicle.curbWeightKg.map { "\($0) кг" } ?? "—")
                }

                Section("Покупка и расходы") {
                    DatePicker("Дата покупки", selection: purchaseDateBinding, displayedComponents: .date)
                    TextField("Счёт / договор поставщика", text: $vehicle.supplierInvoice)
                    Picker("Валюта покупки", selection: $vehicle.currency) {
                        ForEach(["EUR", "USD", "GBP", "CHF", "SEK", "NOK", "DKK", "PLN"], id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    moneyField("Цена покупки, \(vehicle.currency)", value: $vehicle.purchasePrice)
                    moneyField("Курс покупки, ₽ за 1 \(vehicle.currency)", value: $vehicle.fxRate)
                    Picker("Валюта доставки до порта", selection: deliveryCurrencyBinding) {
                        ForEach(currencyOptions, id: \.self) { currency in Text(currency).tag(currency) }
                    }
                    moneyField("Доставка до порта, \(vehicle.deliveryCurrency ?? "RUB")", value: $vehicle.deliveryCost)
                    moneyField("Курс доставки, ₽ за 1 \(vehicle.deliveryCurrency ?? "RUB")", value: deliveryFxRateBinding)
                    Picker("Валюта фрахта", selection: freightCurrencyBinding) {
                        ForEach(currencyOptions, id: \.self) { currency in Text(currency).tag(currency) }
                    }
                    moneyField("Фрахт, \(vehicle.freightCurrency ?? "RUB")", value: $vehicle.freightCost)
                    moneyField("Курс фрахта, ₽ за 1 \(vehicle.freightCurrency ?? "RUB")", value: freightFxRateBinding)
                    Button {
                        Task { await loadCBRRate() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoadingCBRRate { ProgressView().controlSize(.small) }
                            Label(isLoadingCBRRate ? "Загружаю курс…" : "Подставить курс ЦБ", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(isLoadingCBRRate)
                    if let cbrRateMessage {
                        Text(cbrRateMessage)
                            .font(.footnote)
                            .foregroundStyle(cbrRateMessageIsError ? Color.euroAmber : Color.euroGreen)
                    }
                    Text("Покупка, доставка до порта и фрахт вводятся в выбранных валютах и пересчитываются в рубли по своим курсам. Таможенные и прочие расходы ниже указываются в рублях.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Таможня и оформление · ₽") {
                    moneyField("Пошлина, ₽", value: $vehicle.customsDuty)
                    moneyField("Сборы / НДС / акциз, ₽", value: $vehicle.customsFees)
                    moneyField("Утилизационный сбор, ₽", value: $vehicle.recyclingFee)
                    moneyField("Сертификация, ₽", value: $vehicle.certificationCost)
                    moneyField("Регистрация, ₽", value: $vehicle.registrationCost)
                    moneyField("Прочие расходы, ₽", value: $vehicle.otherCosts)
                }

                Section("Продажа") {
                    moneyField("Плановая цена продажи", value: $vehicle.salePrice)
                    moneyField("Предоплата", value: $vehicle.prepayment)
                    Picker("Статус заказа", selection: $vehicle.orderStatus) {
                        ForEach(["Новая заявка", "Подтвержден", "Ожидает оплату", "Ожидает автомобиль", "Автомобиль доставлен", "Закрыт", "Отменен"], id: \.self) { Text($0).tag($0) }
                    }
                    if vehicle.importType == "Под заказ" {
                        DatePicker("Дата заказа", selection: orderDateBinding, displayedComponents: .date)
                        TextField("Договор с клиентом", text: $vehicle.clientContract)
                    }
                    LabeledContent("Себестоимость", value: vehicle.totalCost.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))))
                    LabeledContent("Плановая прибыль", value: vehicle.expectedProfit.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))))
                    moneyField("Фактическая цена продажи, ₽", value: $vehicle.actualSalePrice)
                    if vehicle.actualSalePrice > 0 {
                        LabeledContent("Фактическая прибыль", value: (vehicle.actualSalePrice - vehicle.totalCost).formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))))
                    }
                }

                Section("Документы") {
                    Picker("Статус документов", selection: $vehicle.documentsStatus) {
                        ForEach(["Не проверены", "Неполный комплект", "Полный комплект", "Есть замечания"], id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Заметки") {
                    TextEditor(text: $vehicle.notes).frame(minHeight: 90)
                }
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .formStyle(.grouped)
            .pickerStyle(.menu)
            .tint(.euroGreen)
            .navigationTitle(isNew ? "Новый автомобиль" : "Изменить автомобиль")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.fontWeight(.semibold)
                }
            }
            .sheet(item: $catalogField) { field in
                CatalogChoiceSheet(
                    field: field,
                    choices: choices(for: field),
                    selectedChoice: selectedChoice(for: field),
                    loadError: catalog.loadError
                ) { choice in
                    apply(choice, to: field)
                }
            }
        }
    }

    private var customerSelection: Binding<String> {
        Binding(
            get: { vehicle.customer?.id.uuidString ?? "" },
            set: { id in vehicle.customer = customers.first(where: { $0.id.uuidString == id }) }
        )
    }

    private var purchaseDateBinding: Binding<Date> {
        Binding(get: { vehicle.purchaseDate ?? .now }, set: { vehicle.purchaseDate = $0 })
    }

    private var orderDateBinding: Binding<Date> {
        Binding(get: { vehicle.orderDate ?? .now }, set: { vehicle.orderDate = $0 })
    }

    private let currencyOptions = ["EUR", "USD", "GBP", "CHF", "SEK", "NOK", "DKK", "PLN", "RUB"]

    private var deliveryCurrencyBinding: Binding<String> {
        Binding(get: { vehicle.deliveryCurrency ?? "RUB" }, set: { vehicle.deliveryCurrency = $0 })
    }

    private var deliveryFxRateBinding: Binding<Double> {
        Binding(get: { vehicle.deliveryFxRate ?? 1 }, set: { vehicle.deliveryFxRate = $0 })
    }

    private var freightCurrencyBinding: Binding<String> {
        Binding(get: { vehicle.freightCurrency ?? "RUB" }, set: { vehicle.freightCurrency = $0 })
    }

    private var freightFxRateBinding: Binding<Double> {
        Binding(get: { vehicle.freightFxRate ?? 1 }, set: { vehicle.freightFxRate = $0 })
    }

    private var selectedGeneration: CatalogGeneration? {
        catalog.generations(for: vehicle.make, model: vehicle.model).first { $0.n == vehicle.generation }
    }

    private func availableYears(for generation: CatalogGeneration) -> [Int] {
        guard let start = generation.from else { return [] }
        let end = max(start, generation.to ?? Calendar.current.component(.year, from: .now))
        return Array(start...end)
    }

    private var dimensions: String {
        let values = [vehicle.vehicleLengthMm, vehicle.vehicleWidthMm, vehicle.vehicleHeightMm]
        guard values.contains(where: { $0 != nil }) else { return "—" }
        return values.map { $0.map(String.init) ?? "—" }.joined(separator: " × ") + " мм"
    }

    private func moneyField(_ title: String, value: Binding<Double>) -> some View {
        TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
    }

    @MainActor
    private func loadCBRRate() async {
        isLoadingCBRRate = true
        cbrRateMessage = nil
        defer { isLoadingCBRRate = false }
        do {
            let snapshot = try await CBRCurrencyRatesService.fetchRates(for: vehicle.purchaseDate ?? .now)
            let selectedCurrencies = Set([vehicle.currency, deliveryCurrencyBinding.wrappedValue, freightCurrencyBinding.wrappedValue])
            var rates: [String: Double] = [:]
            var missingCurrencies: [String] = []
            for currency in selectedCurrencies {
                if currency == "RUB" {
                    rates[currency] = 1
                } else if let rate = snapshot.ratesToRuble[currency] {
                    rates[currency] = rate
                } else {
                    missingCurrencies.append(currency)
                }
            }
            guard missingCurrencies.isEmpty else {
                cbrRateMessageIsError = true
                cbrRateMessage = "В ответе Банка России нет курса: \(missingCurrencies.sorted().joined(separator: ", "))."
                return
            }
            vehicle.fxRate = rates[vehicle.currency] ?? 1
            vehicle.deliveryFxRate = rates[deliveryCurrencyBinding.wrappedValue] ?? 1
            vehicle.freightFxRate = rates[freightCurrencyBinding.wrappedValue] ?? 1
            cbrRateMessageIsError = false
            cbrRateMessage = "Подставлены курсы ЦБ на \(snapshot.officialDate.formatted(date: .numeric, time: .omitted))."
        } catch {
            cbrRateMessageIsError = true
            cbrRateMessage = "Не удалось получить курс ЦБ: \(error.localizedDescription)"
        }
    }

    private func catalogButton(_ field: CatalogField, value: String, enabled: Bool) -> some View {
        Button { catalogField = field } label: {
            HStack {
                Text(field.title).foregroundStyle(.primary)
                Spacer()
                Text(value.isEmpty ? "Выбрать" : value).foregroundStyle(value.isEmpty ? .secondary : Color.euroGreen).lineLimit(1)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .disabled(!enabled)
    }

    private func choices(for field: CatalogField) -> [String] {
        switch field {
        case .make: catalog.makes.map(\.make)
        case .model: catalog.models(for: vehicle.make).map(\.n)
        case .generation: catalog.generations(for: vehicle.make, model: vehicle.model).map(\.n)
        case .year: selectedGeneration.map { availableYears(for: $0).map(String.init) } ?? []
        case .engine: enginesForSelectedYear().map(\.n)
        }
    }

    private func selectedChoice(for field: CatalogField) -> String {
        switch field {
        case .make: vehicle.make
        case .model: vehicle.model
        case .generation: vehicle.generation
        case .year: vehicle.year.map(String.init) ?? ""
        case .engine: vehicle.engine
        }
    }

    private func enginesForSelectedYear() -> [CatalogEngine] {
        catalog.engines(for: vehicle.make, model: vehicle.model, generation: vehicle.generation)
            .filter { $0.isAvailable(in: vehicle.year) }
    }

    private func apply(_ choice: String, to field: CatalogField) {
        switch field {
        case .make:
            vehicle.make = choice
            vehicle.model = ""
            vehicle.generation = ""
            vehicle.engine = ""
            clearSpecs()
        case .model:
            vehicle.model = choice
            vehicle.generation = ""
            vehicle.engine = ""
            clearSpecs()
        case .generation:
            vehicle.generation = choice
            vehicle.engine = ""
            clearSpecs()
            if let generation = catalog.generations(for: vehicle.make, model: vehicle.model).first(where: { $0.n == choice }) {
                vehicle.year = generation.from
                vehicle.bodyType = generation.body ?? ""
            }
        case .year:
            guard let year = Int(choice) else { return }
            vehicle.year = year
            vehicle.engine = ""
            clearEngineSpecs()
        case .engine:
            vehicle.engine = choice
            if let engine = enginesForSelectedYear().first(where: { $0.n == choice }) {
                vehicle.engineVolumeCc = engine.cc
                vehicle.enginePowerHp = engine.hp
                vehicle.engineType = engine.localizedFuel
                vehicle.driveType = engine.localizedDrive
                vehicle.transmission = engine.tr ?? ""
                vehicle.vehicleLengthMm = engine.l
                vehicle.vehicleWidthMm = engine.w
                vehicle.vehicleHeightMm = engine.h
                vehicle.wheelbaseMm = engine.wb
                vehicle.curbWeightKg = engine.kg
            }
        }
    }

    private func clearSpecs() {
        clearEngineSpecs()
    }

    private func clearEngineSpecs() {
        vehicle.engineVolumeCc = nil
        vehicle.enginePowerHp = nil
        vehicle.engineType = ""
        vehicle.driveType = ""
        vehicle.transmission = ""
        vehicle.vehicleLengthMm = nil
        vehicle.vehicleWidthMm = nil
        vehicle.vehicleHeightMm = nil
        vehicle.wheelbaseMm = nil
        vehicle.curbWeightKg = nil
    }

    private func save() {
        vehicle.vin = vehicle.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        vehicle.updatedAt = .now
        if isNew { modelContext.insert(vehicle) }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Не удалось сохранить автомобиль: \(error.localizedDescription)"
        }
    }
}

private struct CatalogChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let field: CatalogField
    let choices: [String]
    let selectedChoice: String
    let loadError: String?
    let onChoose: (String) -> Void

    private var filteredChoices: [String] {
        guard !search.isEmpty else { return choices }
        return choices.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: field.symbol)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Color.euroGreen)
                            .frame(width: 48, height: 48)
                            .background(Color.euroGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(field.title)
                                .font(.headline)
                                .foregroundStyle(Color.euroInk)
                            Text(field.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 7) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(Color.euroGreen)
                        Text("\(filteredChoices.count) вариантов")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.weight(.medium))

                    if filteredChoices.isEmpty {
                        ContentUnavailableView(
                            "Нет вариантов",
                            systemImage: field.symbol,
                            description: Text(loadError ?? "Проверьте поиск или выберите предыдущий пункт каталога.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        LazyVStack(spacing: 9) {
                            ForEach(filteredChoices, id: \.self) { choice in
                                let isSelected = choice == selectedChoice
                                Button {
                                    onChoose(choice)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: field.symbol)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(isSelected ? Color.euroGreen : Color.euroInk.opacity(0.48))
                                            .frame(width: 36, height: 36)
                                            .background(isSelected ? Color.euroGreen.opacity(0.12) : Color.euroPanelRaised, in: RoundedRectangle(cornerRadius: 11))
                                        Text(choice)
                                            .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                                            .foregroundStyle(Color.euroInk)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 8)
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(Color.euroGreen)
                                        } else {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Color.euroInk.opacity(0.42))
                                        }
                                    }
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(isSelected ? Color.euroGreen.opacity(0.07) : Color.euroPanel, in: RoundedRectangle(cornerRadius: 15))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(isSelected ? Color.euroGreen.opacity(0.42) : Color.euroLine.opacity(0.85), lineWidth: 1)
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: 15))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: 660)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
            .background(Color.euroCanvas)
            .searchable(text: $search, prompt: "Поиск")
            .navigationTitle(field.title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 430, idealWidth: 560, maxWidth: 760, minHeight: 500, idealHeight: 660)
        #endif
    }
}
