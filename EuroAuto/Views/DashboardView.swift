import SwiftData
import SwiftUI

struct DashboardView: View {
    let onAddVehicle: () -> Void
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    private var inTransit: Int { vehicles.filter { $0.vehicleStatus == "В пути" }.count }
    private var customerOrders: Int { vehicles.filter { $0.importType == "Под заказ" }.count }
    private var portfolio: Double { vehicles.reduce(0) { $0 + $1.totalCost } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("NORD AUTO  /  ОПЕРАЦИОННАЯ СВОДКА")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.euroGreen)
                    Text("Рабочий стол")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.euroInk)
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "ru_RU"))).capitalized + "  ·  Сводка по автомобилям и заказам")
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 14)], spacing: 14) {
                    MetricCard(title: "Автомобилей", value: "\(vehicles.count)", symbol: "car.side.fill", tint: .euroGreen)
                    MetricCard(title: "В пути", value: "\(inTransit)", symbol: "shippingbox.fill", tint: .euroAmber)
                    MetricCard(title: "Заказных", value: "\(customerOrders)", symbol: "person.crop.rectangle.stack.fill", tint: .blue)
                    MetricCard(title: "Вложено", value: portfolio.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))), symbol: "rublesign.circle.fill", tint: .purple)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Последние автомобили")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text("\(vehicles.count) всего")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if vehicles.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "car.side")
                                .font(.system(size: 34))
                                .foregroundStyle(.secondary)
                            Text("Пока нет автомобилей")
                                .font(.headline)
                            Text("Добавьте первую машину, чтобы начать учет.")
                                .foregroundStyle(.secondary)
                            Button(action: onAddVehicle) {
                                Label("Добавить автомобиль", systemImage: "plus")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.euroGreen)
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(vehicles.prefix(6)) { vehicle in
                                NavigationLink(destination: VehicleDetailView(vehicle: vehicle)) {
                                    VehicleRow(vehicle: vehicle)
                                }
                                .buttonStyle(.plain)
                                if vehicle.id != vehicles.prefix(6).last?.id { Divider().padding(.leading, 60) }
                            }
                        }
                        .padding(8)
                        .background(Color.euroPanel, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.euroLine.opacity(0.75), lineWidth: 1))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color.euroCanvas)
        .navigationTitle("Обзор")
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: 23, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Color.euroPanel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.euroLine.opacity(0.8), lineWidth: 1))
    }
}
