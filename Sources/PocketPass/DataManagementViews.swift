import SwiftUI
import UniformTypeIdentifiers

struct ExportDataView: View {
    enum Format: String, CaseIterable, Identifiable {
        case backup = "加密备份"
        case json = "JSON"
        case csv = "CSV"
        case markdown = "Markdown"
        var id: Self { self }
    }

    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var format: Format = .backup
    @State private var password = ""
    @State private var confirmation = ""
    @State private var document = TransferDocument()
    @State private var showingExporter = false
    @State private var errorMessage = ""
    @State private var isPreparing = false
    @State private var processedCount = 0
    @State private var totalCount = 0
    @State private var exportedAccountCount = 0
    @State private var progress = 0.0
    @State private var resultMessage = ""

    private var contentType: UTType {
        switch format {
        case .backup: DataTransferService.backupType
        case .json: .json
        case .csv: .commaSeparatedText
        case .markdown: DataTransferService.markdownType
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("导出数据").font(.title2.bold()); Spacer(); Button("关闭") { dismiss() }.buttonStyle(.bordered).disabled(isPreparing) }
            Picker("格式", selection: $format) { ForEach(Format.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented)
                .disabled(isPreparing)
            if format == .backup {
                Text("备份文件包含账户、分类、标签和图标，并使用独立密码加密。")
                    .font(.caption).foregroundStyle(PocketTheme.muted)
                SecureField("备份密码（至少6位）", text: $password).textFieldStyle(.roundedBorder).disabled(isPreparing)
                SecureField("再次输入备份密码", text: $confirmation).textFieldStyle(.roundedBorder).disabled(isPreparing)
            } else {
                Label("此格式包含明文密码，请妥善保管导出文件。", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            if isPreparing || totalCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress)
                        .tint(PocketTheme.accent)
                    HStack {
                        Text(isPreparing ? "正在准备导出数据" : (resultMessage.isEmpty ? "数据准备完成" : resultMessage))
                        Spacer()
                        Text("\(processedCount) / \(totalCount) 个账户项目")
                    }
                    .font(.caption)
                    .foregroundStyle(resultMessage.isEmpty ? PocketTheme.muted : .green)
                }
                .padding(14)
                .background(PocketTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(isPreparing ? "正在准备…" : "准备并选择保存位置") { prepare() }
                    .buttonStyle(.borderedProminent).tint(PocketTheme.accent).foregroundStyle(.black)
                    .disabled(isPreparing)
            }
        }.padding(24).frame(width: 470).background(PocketTheme.background)
            .buttonBorderShape(.capsule)
            .onChange(of: format) { _, _ in resetProgress() }
            .fileExporter(isPresented: $showingExporter, document: document, contentType: contentType,
                          defaultFilename: exportFilename) { result in
                switch result {
                case .success:
                    resultMessage = "已导出 \(totalCount) 个账户项目、\(exportedAccountCount) 个登录账号"
                    progress = 1
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    resultMessage = ""
                }
            }
    }

    private func prepare() {
        if format == .backup, (password.count < 6 || password != confirmation) {
            errorMessage = "请输入一致的6位以上备份密码"
            return
        }
        var snapshot = store.snapshot
        if format == .csv || format == .markdown {
            snapshot.items.removeAll { $0.deletedAt != nil }
        }
        resetProgress()
        isPreparing = true
        totalCount = snapshot.items.count
        exportedAccountCount = snapshot.items.reduce(0) { $0 + $1.accounts.count }

        Task { @MainActor in
            for (offset, _) in snapshot.items.enumerated() {
                processedCount = offset + 1
                progress = totalCount == 0 ? 0.85 : Double(processedCount) / Double(totalCount) * 0.85
                if offset.isMultiple(of: 4) { try? await Task.sleep(for: .milliseconds(12)) }
                else { await Task.yield() }
            }
            do {
                switch format {
                case .backup:
                    document = .init(data: try DataTransferService.encryptedBackup(snapshot: snapshot, password: password))
                case .json: document = .init(data: try DataTransferService.json(snapshot: snapshot))
                case .csv: document = .init(data: DataTransferService.csv(snapshot: snapshot))
                case .markdown: document = .init(data: DataTransferService.markdown(snapshot: snapshot))
                }
                processedCount = totalCount
                progress = 1
                errorMessage = ""
                isPreparing = false
                showingExporter = true
            } catch {
                errorMessage = error.localizedDescription
                isPreparing = false
            }
        }
    }

    private func resetProgress() {
        processedCount = 0
        totalCount = 0
        exportedAccountCount = 0
        progress = 0
        resultMessage = ""
        errorMessage = ""
    }

    private var exportFilename: String {
        switch format {
        case .backup: "口袋密码备份.pocketpass"
        case .json: "口袋密码导出.json"
        case .csv: "口袋密码导出.csv"
        case .markdown: "口袋密码导出.md"
        }
    }
}

struct ImportDataView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var data: Data?
    @State private var filename = ""
    @State private var password = ""
    @State private var showingImporter = false
    @State private var errorMessage = ""
    @State private var isImporting = false
    @State private var processedCount = 0
    @State private var totalCount = 0
    @State private var progress = 0.0
    @State private var resultMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("导入数据").font(.title2.bold()); Spacer(); Button("关闭") { dismiss() }.buttonStyle(.bordered).disabled(isImporting) }
            Button { showingImporter = true } label: {
                Label(filename.isEmpty ? "选择 .pocketpass、JSON、CSV 或 Markdown 文件" : filename, systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.plain).padding(14).background(PocketTheme.card).clipShape(Capsule()).disabled(isImporting)
            if let data, DataTransferService.isEncryptedBackup(data) {
                SecureField("输入备份密码", text: $password).textFieldStyle(.roundedBorder)
            }
            Text("导入数据将与当前密码库合并；相同 ID 或内容完全相同的账户不会重复导入。")
                .font(.caption).foregroundStyle(PocketTheme.muted)
            if isImporting || totalCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress)
                        .tint(PocketTheme.accent)
                    HStack {
                        Text(isImporting ? "正在导入账户数据" : resultMessage)
                        Spacer()
                        Text("\(processedCount) / \(totalCount) 个账户项目")
                    }
                    .font(.caption)
                    .foregroundStyle(isImporting ? PocketTheme.muted : .green)
                }
                .padding(14)
                .background(PocketTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(isImporting ? "正在导入…" : "开始导入") { importData() }
                    .buttonStyle(.borderedProminent).tint(PocketTheme.accent).foregroundStyle(.black)
                    .disabled(data == nil || isImporting || !resultMessage.isEmpty)
            }
        }.padding(24).frame(width: 500).background(PocketTheme.background)
            .buttonBorderShape(.capsule)
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [DataTransferService.backupType, .json, .commaSeparatedText, DataTransferService.markdownType]) { result in
                guard case .success(let url) = result else { return }
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    data = try Data(contentsOf: url)
                    filename = url.lastPathComponent
                    resetImportProgress()
                }
                catch { errorMessage = error.localizedDescription }
            }
    }

    private func importData() {
        guard let data else { return }
        resetImportProgress()
        isImporting = true
        Task { @MainActor in
            do {
                let snapshot: VaultSnapshot
                if DataTransferService.isEncryptedBackup(data) {
                    snapshot = try DataTransferService.decryptBackup(data, password: password)
                } else if ["md", "markdown"].contains((filename as NSString).pathExtension.lowercased()) {
                    snapshot = try DataTransferService.snapshot(fromMarkdown: data, baseCategories: store.categories)
                } else if let json = try? DataTransferService.snapshot(fromJSON: data) {
                    snapshot = json
                } else {
                    snapshot = try DataTransferService.snapshot(fromCSV: data, baseCategories: store.categories)
                }
                totalCount = snapshot.items.count
                let summary = await store.merge(snapshot) { completed, total in
                    processedCount = completed
                    totalCount = total
                    progress = total == 0 ? 1 : Double(completed) / Double(total)
                }
                processedCount = snapshot.items.count
                totalCount = snapshot.items.count
                progress = 1
                resultMessage = "新增 \(summary.inserted) 个，更新 \(summary.updated) 个，跳过重复 \(summary.skipped) 个；导入 \(summary.accounts) 个登录账号"
                errorMessage = ""
            } catch {
                errorMessage = "导入失败，请检查文件格式和备份密码"
            }
            isImporting = false
        }
    }

    private func resetImportProgress() {
        isImporting = false
        processedCount = 0
        totalCount = 0
        progress = 0
        resultMessage = ""
        errorMessage = ""
    }
}
