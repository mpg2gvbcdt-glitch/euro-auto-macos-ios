import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportData = Data()
    @State private var exporting = false
    @State private var importing = false
    @State private var alert: BackupAlert?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("РЕЗЕРВНОЕ КОПИРОВАНИЕ").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Color.euroGreen)
                    Text("Перенос данных").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Создайте копию карточек и документов или перенесите данные из отчётности.")
                        .foregroundStyle(.secondary)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Полная резервная копия", systemImage: "externaldrive.fill")
                            .font(.headline)
                        Text("В файл войдут заказчики, автомобили, расходы, статусы и все прикреплённые документы. Храните его в надёжном месте: файл содержит персональные данные клиентов.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button(action: prepareExport) {
                            Label("Сохранить копию", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.euroGreen)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Восстановить или перенести", systemImage: "arrow.down.doc.fill").font(.headline)
                        Text("Импорт обновляет совпадающие записи по VIN и ID заказчика, добавляет новые карточки и документы. Существующие записи не удаляются.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button { importing = true } label: {
                            Label("Выбрать файл копии", systemImage: "doc.badge.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
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
        .navigationTitle("Перенос данных")
        .fileExporter(isPresented: $exporting, document: BackupFile(data: exportData), contentType: .json, defaultFilename: "11-35-backup") { result in
            if case .failure(let error) = result { alert = BackupAlert(title: "Не удалось сохранить копию", message: error.localizedDescription) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let report = try PortableBackupService.importBackup(from: url, context: modelContext)
                alert = BackupAlert(title: "Данные перенесены", message: "Заказчиков в файле: \(report.customers). Добавлено автомобилей: \(report.vehicles). Добавлено документов: \(report.documents). Уже существующих документов пропущено: \(report.skippedDocuments).")
            } catch {
                alert = BackupAlert(title: "Не удалось импортировать", message: error.localizedDescription)
            }
        }
        .alert(item: $alert) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("ОК")))
        }
    }

    private func prepareExport() {
        do { exportData = try PortableBackupService.makeBackup(context: modelContext); exporting = true }
        catch { alert = BackupAlert(title: "Не удалось подготовить копию", message: error.localizedDescription) }
    }
}

private struct BackupAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}
