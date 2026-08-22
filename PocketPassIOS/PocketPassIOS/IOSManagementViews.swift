import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct IOSTagManagerView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var newTag = ""
    @State private var editingTag: String?
    @State private var editedName = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("新建标签", text: $newTag)
                    Button("添加") {
                        store.addTag(newTag)
                        newTag = ""
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            Section("已有标签") {
                if store.tags.isEmpty {
                    ContentUnavailableView("暂无标签", systemImage: "tag")
                }
                ForEach(store.tags, id: \.self) { tag in
                    HStack {
                        Label(tag, systemImage: "tag.fill")
                        Spacer()
                        Button("编辑") {
                            editingTag = tag
                            editedName = tag
                        }
                    }
                    .swipeActions {
                        Button("删除", role: .destructive) { store.deleteTag(tag) }
                    }
                }
            }
        }
        .navigationTitle("标签管理")
        .alert("重命名标签", isPresented: Binding(
            get: { editingTag != nil },
            set: { if !$0 { editingTag = nil } }
        )) {
            TextField("标签名称", text: $editedName)
            Button("取消", role: .cancel) { editingTag = nil }
            Button("保存") {
                if let editingTag { store.renameTag(editingTag, to: editedName) }
                editingTag = nil
            }
        }
    }
}

struct IOSCategoryManagerView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var editingCategory: VaultCategory?
    @State private var showEditor = false

    var body: some View {
        List {
            Section {
                ForEach(store.categories) { category in
                    Button {
                        editingCategory = category
                        showEditor = true
                    } label: {
                        HStack(spacing: 14) {
                            IOSVaultIcon(symbol: category.icon, data: category.iconData, size: 42, background: Color(hex: category.colorHex))
                            Text(LocalizedStringKey(category.name))
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("删除", role: .destructive) { store.deleteCategory(category.id) }
                    }
                }
                .onMove(perform: store.moveCategory)
            } footer: {
                Text("长按并拖动可自定义首页分类顺序。删除分类时，账户会自动移到其他分类。")
            }
        }
        .navigationTitle("分类管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCategory = nil
                    showEditor = true
                } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarLeading) { EditButton() }
        }
        .sheet(isPresented: $showEditor) {
            IOSCategoryEditorView(category: editingCategory)
        }
    }
}

struct IOSCategoryEditorView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let category: VaultCategory?
    @State private var name: String
    @State private var symbol: String
    @State private var iconData: Data?
    @State private var colorHex: String
    @State private var showIconPicker = false

    private let colors = ["FDBF02", "F45B5B", "5792E8", "8B6FD6", "4DBB8A", "E45D9B", "51B6C8", "B6824C", "596BCB", "55C8B2", "EABC32", "888888"]

    init(category: VaultCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _symbol = State(initialValue: category?.icon ?? "folder.fill")
        _iconData = State(initialValue: category?.iconData)
        _colorHex = State(initialValue: category?.colorHex ?? "FDBF02")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showIconPicker = true } label: {
                        HStack {
                            IOSVaultIcon(symbol: symbol, data: iconData, size: 64, background: Color(hex: colorHex))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("图标选择").font(.headline)
                                Text("与账户图标使用同一选择器").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    TextField("分类名称", text: $name)
                }
                Section("卡片颜色") {
                    ColorPicker("自选颜色", selection: Binding(
                        get: { Color(hex: colorHex) },
                        set: { colorHex = $0.rgbHex }
                    ), supportsOpacity: false)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                colorHex = color
                            } label: {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 38, height: 38)
                                    .overlay {
                                        if colorHex == color { Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(.white) }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(Text(LocalizedStringKey(category == nil ? "添加分类" : "编辑分类")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(IOSTheme.accent, in: Capsule())
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IOSIconPickerView(symbol: $symbol, iconData: $iconData)
            }
        }
    }

    private func save() {
        if var category {
            category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            category.icon = symbol
            category.iconData = iconData
            category.colorHex = colorHex
            store.updateCategory(category)
        } else {
            store.addCategory(name: name.trimmingCharacters(in: .whitespacesAndNewlines), icon: symbol, iconData: iconData, colorHex: colorHex)
        }
        dismiss()
    }
}

struct IOSIconLibraryView: View {
    @EnvironmentObject private var store: VaultStore
    @EnvironmentObject private var settings: IOSAppSettings
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var importMessage: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            if store.customIcons.isEmpty {
                ContentUnavailableView("图标库为空", systemImage: "photo.on.rectangle.angled", description: Text("最多保存 100 枚自定义图标"))
                    .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.customIcons) { icon in
                        VStack(spacing: 7) {
                            IOSVaultIcon(symbol: "photo", data: icon.data, size: 64, background: IOSTheme.input)
                            Text(icon.name).font(.caption2).lineLimit(1)
                        }
                        .contextMenu {
                            Button("删除", systemImage: "trash", role: .destructive) { store.deleteCustomIcon(icon.id) }
                        }
                    }
                }
                .padding(18)
            }
        }
        .background(IOSTheme.background)
        .navigationTitle("图标库")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: max(1, 100 - store.customIcons.count), matching: .images) {
                    Image(systemName: "plus")
                }
            }
        }
        .onChange(of: selectedPhotos) { _, photos in
            Task { await importPhotos(photos) }
        }
        .alert("图标库", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button("好") { importMessage = nil }
        } message: { Text(importMessage ?? "") }
    }

    private func importPhotos(_ photos: [PhotosPickerItem]) async {
        var icons: [CustomIcon] = []
        for (index, photo) in photos.enumerated() {
            guard let data = try? await photo.loadTransferable(type: Data.self), data.count <= 20_000_000,
                  let normalized = IOSImageProcessor.normalizedIconData(data) else { continue }
            icons.append(CustomIcon(name: "自定义图标 \(store.customIcons.count + index + 1)", data: normalized))
        }
        let added = store.addCustomIcons(icons)
        selectedPhotos = []
        importMessage = settings.language.text("已添加 \(added) 枚图标", "Added \(added) icons")
    }
}

enum IOSExportFormat: String, CaseIterable, Identifiable {
    case encrypted = "加密备份"
    case json = "JSON"
    case csv = "CSV"
    case markdown = "Markdown"
    var id: Self { self }
    var fileExtension: String {
        switch self { case .encrypted: "pocketpass"; case .json: "json"; case .csv: "csv"; case .markdown: "md" }
    }
}

struct IOSVaultDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .json, .commaSeparatedText, .plainText] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct IOSDataManagementView: View {
    enum Mode { case importData, exportData }
    @EnvironmentObject private var store: VaultStore
    @EnvironmentObject private var settings: IOSAppSettings
    let mode: Mode
    @State private var format: IOSExportFormat = .encrypted
    @State private var password = ""
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument = IOSVaultDocument()
    @State private var exportFilename = "PocketPass-备份"
    @State private var isWorking = false
    @State private var progress = 0.0
    @State private var resultMessage: String?

    var body: some View {
        Form {
            if mode == .exportData {
                Section("格式") {
                    Picker("导出格式", selection: $format) {
                        ForEach(IOSExportFormat.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                    }
                    if format == .encrypted {
                        SecureField("备份密码（至少 6 位）", text: $password)
                    } else {
                        Label("此格式包含明文密码，请妥善保管。", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    Button { prepareExport() } label: {
                        Label("开始导出", systemImage: "square.and.arrow.up")
                    }
                    .disabled(format == .encrypted && password.count < 6)
                }
            } else {
                Section {
                    Label("支持 .pocketpass、.json、.csv 和 .md；重复数据会自动跳过。", systemImage: "checkmark.shield.fill")
                    SecureField("加密备份密码（如适用）", text: $password)
                    Button { showImporter = true } label: {
                        Label("选择文件并导入", systemImage: "square.and.arrow.down")
                    }
                }
            }
            if isWorking || progress > 0 {
                Section("进度") {
                    ProgressView(value: progress)
                    Text(progress >= 1 ? "已完成" : "正在处理…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(Text(LocalizedStringKey(mode == .importData ? "导入数据" : "导出数据")))
        .fileImporter(isPresented: $showImporter, allowedContentTypes: IOSVaultDocument.readableContentTypes) { result in
            handleImport(result)
        }
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .data, defaultFilename: exportFilename) { result in
            isWorking = false
            progress = 1
            switch result {
            case .success:
                resultMessage = settings.language.text(
                    "已导出 \(store.activeItems().count) 个账户项目",
                    "Exported \(store.activeItems().count) account items"
                )
            case .failure(let error): resultMessage = error.localizedDescription
            }
        }
        .alert("数据处理结果", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button("好") { resultMessage = nil }
        } message: { Text(resultMessage ?? "") }
    }

    private func prepareExport() {
        isWorking = true
        progress = 0.25
        let snapshot = store.snapshot
        let selectedFormat = format
        let backupPassword = password
        Task {
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    switch selectedFormat {
                    case .encrypted: try VaultDataTransfer.encryptedBackup(snapshot: snapshot, password: backupPassword)
                    case .json: try VaultDataTransfer.json(snapshot: snapshot)
                    case .csv: VaultDataTransfer.csv(snapshot: snapshot)
                    case .markdown: VaultDataTransfer.markdown(snapshot: snapshot)
                    }
                }.value
                exportDocument = IOSVaultDocument(data: data)
                exportFilename = "PocketPass-\(ISO8601DateFormatter().string(from: .now).prefix(10)).\(selectedFormat.fileExtension)"
                progress = 0.75
                showExporter = true
            } catch {
                isWorking = false
                resultMessage = error.localizedDescription
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        isWorking = true
        progress = 0.1
        Task {
            do {
                let url = try result.get()
                let backupPassword = password
                let baseCategories = store.categories
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
                    defer { url.stopAccessingSecurityScopedResource() }
                    let data = try VaultDataTransfer.importData(from: url)
                    switch url.pathExtension.lowercased() {
                    case "pocketpass": return try VaultDataTransfer.decryptBackup(data, password: backupPassword)
                    case "json": return try VaultDataTransfer.snapshot(fromJSON: data)
                    case "csv": return try VaultDataTransfer.snapshot(fromCSV: data, baseCategories: baseCategories)
                    case "md", "markdown", "txt": return try VaultDataTransfer.snapshot(fromMarkdown: data, baseCategories: baseCategories)
                    default:
                        if VaultDataTransfer.isEncryptedBackup(data) { return try VaultDataTransfer.decryptBackup(data, password: backupPassword) }
                        return try VaultDataTransfer.snapshot(fromJSON: data)
                    }
                }.value
                progress = 0.75
                let result = store.merge(snapshot)
                progress = 1
                isWorking = false
                resultMessage = settings.language.text(
                    "导入完成：新增 \(result.inserted)，更新 \(result.updated)，跳过重复 \(result.skipped)",
                    "Import complete: \(result.inserted) added, \(result.updated) updated, \(result.skipped) duplicates skipped"
                )
            } catch {
                isWorking = false
                resultMessage = settings.language.text("导入失败：\(error.localizedDescription)", "Import failed: \(error.localizedDescription)")
            }
        }
    }
}

struct IOSVaultIcon: View {
    let symbol: String
    let data: Data?
    let size: CGFloat
    let background: Color

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: symbol).resizable().scaledToFit().padding(size * 0.25).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(background, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

struct IOSAboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                IOSBrandMark(size: 96)
                VStack(spacing: 6) {
                    Text("口袋密码").font(.largeTitle.bold())
                    Text("PocketPass").font(.headline).foregroundStyle(.secondary)
                }
                Text("本地优先的原生账户密码管理器，支持多登录账号、自定义字段、分类、标签、图片附件、密码生成和多格式数据迁移。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text(versionText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 560)
            .padding(32)
        }
        .background(IOSTheme.background)
        .navigationTitle("关于口袋密码")
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "3"
        return "V\(version)(\(build))"
    }
}

struct IOSPrivacyView: View {
    var body: some View {
        List {
            Section("本地数据") {
                Label("账户数据在写入设备前使用 AES-GCM 加密。", systemImage: "lock.shield.fill")
                Label("当前版本不接入 iCloud，不会上传账户和密码。", systemImage: "icloud.slash.fill")
            }
            Section("网络访问") {
                Label("仅在你主动搜索 App Store 图标或获取网站图标时访问网络。", systemImage: "network")
                Label("所选相册图片仅用于账户附件或自定义图标。", systemImage: "photo.fill")
            }
            Section("剪贴板") {
                Label("复制的字段将在 30 秒后自动清除；如果剪贴板内容已变化则不会覆盖。", systemImage: "doc.on.clipboard.fill")
            }
        }
        .navigationTitle("隐私说明")
    }
}
