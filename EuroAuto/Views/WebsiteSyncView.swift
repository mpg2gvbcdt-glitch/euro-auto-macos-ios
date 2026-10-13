import SwiftData
import SwiftUI

struct WebsiteSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var server = WebsiteSyncService.savedServer
    @State private var password = ""
    @State private var syncing = false
    @State private var message: String?
    @State private var isError = false
    @AppStorage("11-35.sync.autoStatus") private var autoSyncStatus = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ДОСТУП С MAC И IPHONE").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Color.euroGreen)
                    Text("Синхронизация").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Передавайте карточки и документы между устройствами через защищённый сервер 11/35.")
                        .foregroundStyle(.secondary)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Подключение к 11/35", systemImage: "lock.icloud.fill").font(.headline)
                        TextField("Адрес сервера", text: $server)
                            .textContentType(.URL)
                            #if os(iOS)
                            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                            #endif
                        SecureField(WebsiteSyncService.hasPassword ? "Пароль уже сохранён — введите новый, чтобы заменить" : "Пароль сайта 11/35", text: $password)
                            .textContentType(.password)
                        Button {
                            Task { await runSync() }
                        } label: {
                            HStack {
                                if syncing { ProgressView().tint(.white) }
                                Label(syncing ? "Синхронизация…" : "Синхронизировать сейчас", systemImage: "arrow.triangle.2.circlepath.icloud")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.euroGreen).disabled(syncing)
                        if WebsiteSyncService.hasPassword {
                            Button("Удалить пароль с этого устройства", role: .destructive) {
                                do {
                                    try WebsiteSyncService.forgetPassword()
                                    message = "Сохранённый пароль удалён с этого устройства."
                                    isError = false
                                } catch {
                                    message = error.localizedDescription
                                    isError = true
                                }
                            }
                            .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }

                if let message {
                    Label(message, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(isError ? Color.red : Color.euroGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).background(Color.euroPanel, in: RoundedRectangle(cornerRadius: 14))
                }

                if !autoSyncStatus.isEmpty {
                    Label(autoSyncStatus, systemImage: autoSyncStatus.contains("не удалась") ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath.icloud")
                        .font(.subheadline).foregroundStyle(autoSyncStatus.contains("не удалась") ? Color.orange : Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).background(Color.euroPanel, in: RoundedRectangle(cornerRadius: 14))
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Как это работает", systemImage: "info.circle").font(.headline)
                        Text("Один раз войдите на каждом устройстве кнопкой выше, чтобы сохранить пароль. После этого карточки автомобилей, расходы, заказчики и документы будут синхронизироваться автоматически после сохранения и при открытии приложения, если есть интернет. Кнопка выше остаётся для принудительной синхронизации. Пароль хранится только в Связке ключей устройства.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("Без интернета изменения останутся на устройстве и отправятся при следующем открытии приложения с подключением. Уже сохранённые записи и файлы доступны офлайн.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color.euroCanvas)
        .groupBoxStyle(EuroAutoGroupBoxStyle())
        .navigationTitle("Синхронизация")
    }

    @MainActor
    private func runSync() async {
        syncing = true
        message = nil
        defer { syncing = false }
        do {
            let report = try await WebsiteSyncService.synchronize(server: server, password: password, context: modelContext)
            password = ""
            message = "Готово. " + report.summary
            autoSyncStatus = "Автоматическая синхронизация настроена на этом устройстве."
            isError = false
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }
}
