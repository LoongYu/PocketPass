import SwiftUI

struct IOSRootView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab = 0
    @State private var showAddAccount = false

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                IOSIPadRootView(selectedTab: $selectedTab, showAddAccount: $showAddAccount)
            } else {
                phoneTabs
            }
        }
        .sheet(isPresented: $showAddAccount) {
            IOSAccountEditorView()
                .environmentObject(store)
        }
    }

    private var phoneTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { IOSHomeView(showAddAccount: $showAddAccount) }
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(0)

            NavigationStack { IOSCategoriesView() }
                .tabItem { Label("分类", systemImage: "square.grid.2x2.fill") }
                .tag(1)

            NavigationStack { IOSTrashView() }
                .tabItem { Label("回收站", systemImage: "trash.fill") }
                .tag(2)

            NavigationStack { IOSSettingsView() }
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(IOSTheme.accent)
    }
}

struct IOSIPadRootView: View {
    @Binding var selectedTab: Int
    @Binding var showAddAccount: Bool

    var body: some View {
        NavigationSplitView {
            List {
                Section {
                    HStack(spacing: 12) {
                        IOSBrandMark(size: 44)
                        VStack(alignment: .leading) {
                            Text("口袋密码").font(.headline)
                            Text("本地密码库").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                sidebarButton("首页", icon: "house.fill", tab: 0)
                sidebarButton("分类", icon: "square.grid.2x2.fill", tab: 1)
                sidebarButton("回收站", icon: "trash.fill", tab: 2)
                sidebarButton("设置", icon: "gearshape.fill", tab: 3)
            }
            .navigationTitle("")
            .safeAreaInset(edge: .bottom) {
                Button { showAddAccount = true } label: {
                    Label("添加账户", systemImage: "plus").fontWeight(.bold).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 13).background(IOSTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain).padding()
            }
        } detail: {
            NavigationStack {
                switch selectedTab {
                case 1: IOSCategoriesView()
                case 2: IOSTrashView()
                case 3: IOSSettingsView()
                default: IOSHomeView(showAddAccount: $showAddAccount)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(IOSTheme.accent)
    }

    private func sidebarButton(_ title: String, icon: String, tab: Int) -> some View {
        Button { selectedTab = tab } label: {
            Label { Text(LocalizedStringKey(title)) } icon: { Image(systemName: icon) }
                .fontWeight(selectedTab == tab ? .bold : .regular)
                .foregroundStyle(selectedTab == tab ? .black : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(selectedTab == tab ? IOSTheme.accent : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }
}

struct IOSHomeView: View {
    @EnvironmentObject private var store: VaultStore
    @EnvironmentObject private var settings: IOSAppSettings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var showAddAccount: Bool
    @State private var searchText = ""
    @State private var selectedCategoryID: UUID?
    @State private var selectedItem: VaultItem?
    @State private var showGenerator = false
    @State private var isSelecting = false
    @State private var selection: Set<UUID> = []
    @State private var confirmBatchDelete = false

    private var visibleItems: [VaultItem] {
        let items = store.activeItems(categoryID: selectedCategoryID, searchText: searchText)
        switch settings.homeSort {
        case .recentlyModified: return items.sorted { $0.modifiedAt > $1.modifiedAt }
        case .name: return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .category:
            let names = Dictionary(uniqueKeysWithValues: store.categories.map { ($0.id, $0.name) })
            return items.sorted { (names[$0.categoryID] ?? "") < (names[$1.categoryID] ?? "") }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            IOSTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    searchBar
                    overview
                    categoryStrip
                    accountList
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 92)
            }
            addButton
            if isSelecting, !selection.isEmpty {
                Button(role: .destructive) { confirmBatchDelete = true } label: {
                    Label("删除已选 \(selection.count) 项", systemImage: "trash.fill")
                        .fontWeight(.bold).foregroundStyle(.white).padding(.horizontal, 18).padding(.vertical, 13).background(.red, in: Capsule())
                }
                .buttonStyle(.plain).padding(.bottom, 18)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedItem) { item in
            IOSAccountDetailView(item: item)
        }
        .sheet(isPresented: $showGenerator) {
            IOSPasswordGeneratorView()
        }
        .confirmationDialog("批量移到回收站？", isPresented: $confirmBatchDelete) {
            Button("移到回收站", role: .destructive) {
                store.moveToTrash(selection)
                selection = []
                isSelecting = false
            }
            Button("取消", role: .cancel) {}
        }
        .onChange(of: store.categories.map(\.id)) { _, categoryIDs in
            if let selectedCategoryID, !categoryIDs.contains(selectedCategoryID) {
                self.selectedCategoryID = nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            IOSBrandMark(size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text("口袋密码")
                    .font(.title2.bold())
                Text("本地密码库")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("搜索账户", text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .background(IOSTheme.panel, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("总览").font(.headline)
                    Text("安全保存，随时取用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showGenerator = true
                } label: {
                    Label("生成密码", systemImage: "wand.and.stars")
                        .font(.caption.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(IOSTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                summaryMetric(value: store.activeItems().count, title: "账户", icon: "key.fill")
                summaryMetric(value: store.categories.count, title: "分类", icon: "square.grid.2x2.fill")
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [IOSTheme.accentDeep.opacity(0.94), IOSTheme.accent.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func summaryMetric(value: Int, title: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(IOSTheme.accent)
            Text("\(value)").font(.headline.bold())
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                categoryChip("全部", icon: "square.grid.2x2.fill", id: nil)
                ForEach(store.categories) { category in
                    categoryChip(category.name, icon: category.icon, id: category.id)
                }
            }
        }
    }

    private func categoryChip(_ title: String, icon: String, id: UUID?) -> some View {
        Button {
            withAnimation(.snappy) { selectedCategoryID = id }
        } label: {
            Label { Text(LocalizedStringKey(title)) } icon: { Image(systemName: icon) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedCategoryID == id ? Color.black : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(selectedCategoryID == id ? IOSTheme.accent : IOSTheme.panel, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var accountList: some View {
        LazyVStack(spacing: 12) {
            HStack {
                Text("账户").font(.headline)
                Spacer()
                Button(isSelecting ? "完成" : "批量管理") {
                    withAnimation { isSelecting.toggle(); if !isSelecting { selection = [] } }
                }
                .font(.caption.weight(.semibold))
                Text(settings.language == .english ? "\(visibleItems.count) items" : "\(visibleItems.count) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if visibleItems.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text(LocalizedStringKey(searchText.isEmpty ? "暂无账户" : "未找到匹配账户"))
                    } icon: {
                        Image(systemName: searchText.isEmpty ? "key" : "magnifyingglass")
                    }
                } description: {
                    if !searchText.isEmpty {
                        Text("请尝试其它关键词或分类")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ForEach(visibleItems) { item in
                    Button {
                        if isSelecting {
                            if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) }
                        } else {
                            selectedItem = item
                        }
                    } label: {
                        HStack(spacing: 14) {
                            if isSelecting {
                                Image(systemName: selection.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection.contains(item.id) ? IOSTheme.accent : .secondary)
                            }
                            IOSVaultIcon(symbol: item.symbol, data: item.iconData, size: 52, background: IOSTheme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).font(.headline)
                                Text(item.accounts.first?.summaryValue ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(LocalizedStringKey(store.categories.first(where: { $0.id == item.categoryID })?.name ?? "其他"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .iosPanel(radius: 20)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            showAddAccount = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 58, height: 58)
                .background(IOSTheme.accent, in: Circle())
                .shadow(color: .black.opacity(0.24), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityLabel("添加账户")
        .opacity(isSelecting || horizontalSizeClass == .regular ? 0 : 1)
        .allowsHitTesting(!isSelecting && horizontalSizeClass != .regular)
    }
}

struct IOSCategoriesView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var showEditor = false
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            IOSTheme.background.ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.categories) { category in
                        NavigationLink {
                            IOSCategoryAccountsView(category: category)
                        } label: {
                            VStack(alignment: .leading, spacing: 28) {
                                HStack {
                                    IOSVaultIcon(symbol: category.icon, data: category.iconData, size: 38, background: .white.opacity(0.18))
                                    Spacer()
                                    Text("\(store.activeItems(categoryID: category.id).count)")
                                        .font(.headline)
                                }
                                Text(LocalizedStringKey(category.name)).font(.headline)
                            }
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(LinearGradient(colors: [Color(hex: category.colorHex), Color(hex: category.colorHex).opacity(0.68)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("分类")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditor = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(destination: IOSCategoryManagerView()) { Image(systemName: "slider.horizontal.3") }
            }
        }
        .sheet(isPresented: $showEditor) { IOSCategoryEditorView(category: nil) }
    }
}

struct IOSCategoryAccountsView: View {
    @EnvironmentObject private var store: VaultStore
    let category: VaultCategory
    @State private var selectedItem: VaultItem?

    var body: some View {
        List(store.activeItems(categoryID: category.id)) { item in
            Button { selectedItem = item } label: {
                HStack(spacing: 12) {
                    IOSVaultIcon(symbol: item.symbol, data: item.iconData, size: 44, background: Color(hex: category.colorHex))
                    VStack(alignment: .leading) {
                        Text(item.name).font(.headline)
                        Text(item.accounts.first?.summaryValue ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(Text(LocalizedStringKey(category.name)))
        .overlay {
            if store.activeItems(categoryID: category.id).isEmpty {
                ContentUnavailableView("暂无账户", systemImage: category.icon)
            }
        }
        .sheet(item: $selectedItem) { IOSAccountDetailView(item: $0) }
    }
}

struct IOSTrashView: View {
    @EnvironmentObject private var store: VaultStore

    var body: some View {
        ZStack {
            IOSTheme.background.ignoresSafeArea()
            if store.trashedItems.isEmpty {
                ContentUnavailableView("回收站为空", systemImage: "trash", description: Text("删除的账户将在这里保留 30 天"))
            } else {
                List(store.trashedItems) { item in
                    HStack {
                        Label(item.name, systemImage: item.symbol)
                        Spacer()
                        Button("恢复") { store.restore([item.id]) }
                            .buttonStyle(.bordered)
                    }
                    .listRowBackground(IOSTheme.panel)
                    .swipeActions {
                        Button("永久删除", role: .destructive) { store.permanentlyDelete([item.id]) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("回收站")
    }
}

struct IOSSettingsView: View {
    @EnvironmentObject private var settings: IOSAppSettings

    var body: some View {
        ZStack {
            IOSTheme.background.ignoresSafeArea()
            Form {
                Section("安全") {
                    Toggle(isOn: $settings.appLockEnabled) {
                        Label("启用应用锁", systemImage: "lock.fill")
                    }
                    Picker("自动锁定", selection: $settings.lockAfterSeconds) {
                        Text("立即").tag(0)
                        Text("1 分钟").tag(60)
                        Text("5 分钟").tag(300)
                        Text("15 分钟").tag(900)
                        Text("30 分钟").tag(1_800)
                    }
                }
                Section("iCloud 同步") {
                    LabeledContent {
                        Text("规划中").foregroundStyle(IOSTheme.accent)
                    } label: {
                        Label("iCloud 同步", systemImage: "icloud.fill")
                    }
                    Text("当前版本不接入 iCloud，数据保存在设备本地加密密码库中。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("通用") {
                    Picker("主题", selection: $settings.appearance) {
                        ForEach(IOSAppearance.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                    }
                    Picker("语言", selection: language) {
                        Text("简体中文").tag(IOSAppLanguage.simplifiedChinese)
                        Text("English").tag(IOSAppLanguage.english)
                    }
                    Picker("首页排序", selection: $settings.homeSort) {
                        ForEach(IOSHomeSort.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                    }
                }
                Section("内容") {
                    NavigationLink(destination: IOSTagManagerView()) { Label("标签管理", systemImage: "tag.fill") }
                    NavigationLink(destination: IOSIconLibraryView()) { Label("图标库", systemImage: "photo.on.rectangle.angled") }
                    NavigationLink(destination: IOSCategoryManagerView()) { Label("分类管理", systemImage: "square.grid.2x2.fill") }
                }
                Section {
                    NavigationLink(destination: IOSDataManagementView(mode: .importData)) { Label("导入数据", systemImage: "square.and.arrow.down") }
                    NavigationLink(destination: IOSDataManagementView(mode: .exportData)) { Label("导出数据", systemImage: "square.and.arrow.up") }
                } header: {
                    Text("数据")
                } footer: {
                    Text(settings.language.text(
                        ".pocketpass 与 JSON 可完整迁移图标；CSV 和 Markdown 为纯文本。",
                        ".pocketpass and JSON preserve icons; CSV and Markdown are text-only."
                    ))
                }
                Section("关于") {
                    NavigationLink(destination: IOSAboutView()) { Label("关于口袋密码", systemImage: "info.circle.fill") }
                    NavigationLink(destination: IOSPrivacyView()) { Label("隐私说明", systemImage: "hand.raised.fill") }
                    LabeledContent("版本", value: versionText)
                    LabeledContent("品牌", value: "PocketPass")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("设置")
    }

    private var language: Binding<IOSAppLanguage> {
        Binding(get: { settings.language }, set: { settings.language = $0 })
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "3"
        return "V\(version)(\(build))"
    }
}
