import SwiftUI

struct RootView: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        Group {
            if store.showingLockScreen {
                LockOverlay()
            } else {
                ZStack {
                    PocketTheme.background.ignoresSafeArea()
                    HStack(spacing: 18) {
                        RailView()
                        Group {
                            if store.selectedSection == .settings {
                                SettingsView()
                            } else if store.selectedSection == .categories {
                                CategoryManagementView()
                            } else {
                                VaultView()
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .buttonBorderShape(.capsule)
        .sheet(isPresented: Bindable(store).showingAddItem) { AddItemView() }
        .sheet(isPresented: Bindable(store).showingAddCategory) { AddCategoryView() }
        .onChange(of: store.showingLockScreen) { _, isLocked in
            guard isLocked else { return }
            store.showingAddItem = false
            store.showingAddCategory = false
        }
        .alert("本地密码库错误", isPresented: Binding(
            get: { store.storageError != nil },
            set: { if !$0 { store.storageError = nil } }
        )) {
            Button("好") { store.storageError = nil }
        } message: {
            Text(store.storageError ?? "发生未知错误")
        }
    }
}

private struct RailView: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        VStack(spacing: 18) {
            InterfaceBrandLogoView(size: 38)
                .frame(width: 58, height: 58)
            .padding(.bottom, 10)

            ForEach(AppSection.allCases) { section in
                Button {
                    store.selectedSection = section
                    store.selectedCategoryID = nil
                    store.selectedItemID = store.visibleItems.first?.id
                } label: {
                    Image(systemName: section.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 50, height: 50)
                        .background(store.selectedSection == section ? PocketTheme.accent : .clear)
                        .foregroundStyle(store.selectedSection == section ? .black : PocketTheme.muted)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(section.title)
            }

            Spacer()
            Button { store.showingAddItem = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .frame(width: 52, height: 52)
                    .background(PocketTheme.accent)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("添加账户")
        }
        .frame(width: 66)
    }
}

private struct VaultView: View {
    var body: some View {
        HStack(spacing: 18) {
            AccountBrowser().frame(minWidth: 510)
            DetailColumn().frame(minWidth: 360, maxWidth: 440)
        }
    }
}

private struct AccountBrowser: View {
    @Environment(VaultStore.self) private var store
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var confirmingBatchDelete = false

    private var visibleIDs: Set<UUID> { Set(store.visibleItems.map(\.id)) }

    private var confirmationTitle: String {
        if store.selectedSection == .trash {
            store.appLanguage.text("永久删除 \(selectedIDs.count) 个账户？", "Permanently delete \(selectedIDs.count) accounts?")
        } else {
            store.appLanguage.text("将 \(selectedIDs.count) 个账户移到回收站？", "Move \(selectedIDs.count) accounts to Trash?")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.selectedSection == .trash {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("回收站").font(.title2.bold())
                        Text("删除项目将在 30 天后清除")
                            .font(.caption).foregroundStyle(PocketTheme.muted)
                    }
                    Spacer()
                    selectionModeButton
                }
            }

            if store.selectedSection == .home {
                HStack(spacing: 10) {
                    CategoryStrip()
                    selectionModeButton
                }
            }

            if isSelecting {
                batchToolbar
            }

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(PocketTheme.muted)
                TextField("搜索账户、网址或标签", text: Bindable(store).searchText)
                    .textFieldStyle(.plain)
            }
            .padding(12).background(PocketTheme.card).clipShape(RoundedRectangle(cornerRadius: 13))

            if store.visibleItems.isEmpty {
                ContentUnavailableView("暂无账户", systemImage: "key.horizontal", description: Text("点击添加账户，建立你的本地密码库"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(store.visibleItems) { item in
                            AccountRow(
                                item: item,
                                isSelecting: isSelecting,
                                isSelected: selectedIDs.contains(item.id)
                            ) {
                                toggleSelection(item.id)
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .pocketPanel()
        .onChange(of: store.selectedSection) { _, _ in stopSelecting() }
        .onChange(of: store.selectedCategoryID) { _, _ in selectedIDs.formIntersection(visibleIDs) }
        .onChange(of: store.searchText) { _, _ in selectedIDs.formIntersection(visibleIDs) }
        .onChange(of: visibleIDs) { _, newValue in
            selectedIDs.formIntersection(newValue)
            if newValue.isEmpty { stopSelecting() }
        }
        .confirmationDialog(confirmationTitle, isPresented: $confirmingBatchDelete, titleVisibility: .visible) {
            if store.selectedSection == .trash {
                Button("永久删除", role: .destructive) { performPermanentDelete() }
            } else {
                Button("移到回收站", role: .destructive) { performMoveToTrash() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if store.selectedSection == .trash {
                Text("此操作无法撤销。")
            } else {
                Text("删除的账户将在回收站保留 30 天。")
            }
        }
    }

    private var selectionModeButton: some View {
        Button(isSelecting ? "取消" : "选择") {
            isSelecting ? stopSelecting() : (isSelecting = true)
        }
        .font(.caption.bold())
        .padding(.horizontal, 13).padding(.vertical, 8)
        .background(isSelecting ? PocketTheme.elevated : PocketTheme.card)
        .foregroundStyle(PocketTheme.primary)
        .clipShape(Capsule())
        .buttonStyle(.plain)
        .disabled(store.visibleItems.isEmpty && !isSelecting)
    }

    private var batchToolbar: some View {
        HStack(spacing: 10) {
            Label("已选择 \(selectedIDs.count) 项", systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(selectedIDs.isEmpty ? PocketTheme.muted : PocketTheme.accent)
            Spacer()
            Button(selectedIDs == visibleIDs && !visibleIDs.isEmpty ? "取消全选" : "全选") {
                if selectedIDs == visibleIDs { selectedIDs.removeAll() }
                else { selectedIDs = visibleIDs }
            }
            .batchActionStyle()

            if store.selectedSection == .trash {
                Button { performRestore() } label: {
                    Label("恢复", systemImage: "arrow.uturn.backward")
                }
                .batchActionStyle()
                .disabled(selectedIDs.isEmpty)
            }

            Button { confirmingBatchDelete = true } label: {
                Label(store.selectedSection == .trash ? "永久删除" : "删除", systemImage: "trash")
            }
            .batchActionStyle(isDestructive: true)
            .disabled(selectedIDs.isEmpty)
        }
        .padding(10)
        .background(PocketTheme.inset)
        .clipShape(Capsule())
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    private func stopSelecting() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    private func performMoveToTrash() {
        store.moveToTrash(selectedIDs)
        stopSelecting()
        store.selectedItemID = store.visibleItems.first?.id
    }

    private func performRestore() {
        store.restore(selectedIDs)
        stopSelecting()
        store.selectedItemID = store.visibleItems.first?.id
    }

    private func performPermanentDelete() {
        store.permanentlyDelete(selectedIDs)
        stopSelecting()
        store.selectedItemID = store.visibleItems.first?.id
    }
}

private extension View {
    func batchActionStyle(isDestructive: Bool = false) -> some View {
        self
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(isDestructive ? Color.red : PocketTheme.primary)
            .background(PocketTheme.card)
            .clipShape(Capsule())
            .buttonStyle(.plain)
    }
}

private struct CategoryStrip: View {
    @Environment(VaultStore.self) private var store

    private var leadingCategories: ArraySlice<VaultCategory> {
        store.categories.prefix(5)
    }

    private var overflowCategories: ArraySlice<VaultCategory> {
        store.categories.dropFirst(5)
    }

    private var selectedOverflowCategory: VaultCategory? {
        overflowCategories.first { $0.id == store.selectedCategoryID }
    }

    var body: some View {
        HStack(spacing: 9) {
            CategoryPill(name: "全部", icon: "square.grid.2x2.fill", color: PocketTheme.accent,
                         selected: store.selectedCategoryID == nil) { store.selectedCategoryID = nil }
            ForEach(leadingCategories) { category in
                CategoryPill(name: category.name, icon: category.icon, iconData: category.iconData, color: category.color,
                             selected: store.selectedCategoryID == category.id) {
                    store.selectedCategoryID = category.id
                }
            }

            if !overflowCategories.isEmpty {
                Menu {
                    ForEach(overflowCategories) { category in
                        Button {
                            store.selectedCategoryID = category.id
                        } label: {
                            if store.selectedCategoryID == category.id {
                                Label(LocalizedStringKey(category.name), systemImage: "checkmark")
                            } else {
                                Text(LocalizedStringKey(category.name))
                            }
                        }
                    }
                } label: {
                    CategoryOverflowLabel(category: selectedOverflowCategory)
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct CategoryOverflowLabel: View {
    let category: VaultCategory?

    var body: some View {
        HStack(spacing: 6) {
            if let category {
                if let iconData = category.iconData, let image = NSImage(data: iconData) {
                    Image(nsImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 15, height: 15)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: category.icon)
                }
                Text(LocalizedStringKey(category.name)).lineLimit(1)
            } else {
                Image(systemName: "ellipsis")
                Text("更多")
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
        }
        .font(.caption.bold())
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(category?.color.opacity(0.85) ?? PocketTheme.card)
        .foregroundStyle(category == nil ? PocketTheme.primary.opacity(0.75) : Color.black)
        .clipShape(Capsule())
    }
}

private struct CategoryPill: View {
    let name: String
    let icon: String
    var iconData: Data? = nil
    let color: Color
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let iconData, let image = NSImage(data: iconData) {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: 15, height: 15).clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: icon)
                }
                Text(LocalizedStringKey(name))
            }
                .font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 9)
                .background(selected ? color.opacity(0.85) : PocketTheme.card)
                .foregroundStyle(selected ? Color.black : PocketTheme.primary.opacity(0.75))
                .clipShape(Capsule())
        }.buttonStyle(.plain)
    }
}

private struct AccountRow: View {
    @Environment(VaultStore.self) private var store
    let item: VaultItem
    var isSelecting = false
    var isSelected = false
    var selectionAction: () -> Void = {}
    var body: some View {
        Button {
            if isSelecting { selectionAction() }
            else { store.selectedItemID = item.id }
        } label: {
            HStack(spacing: 14) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? PocketTheme.accent : PocketTheme.muted)
                        .frame(width: 22)
                }
                VaultIconView(symbol: item.symbol, data: item.iconData)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.headline)
                    Text(item.accounts.first?.username ?? "未填写账号").font(.caption).foregroundStyle(PocketTheme.muted)
                }
                Spacer()
                if item.isFavorite { Image(systemName: "bookmark.fill").foregroundStyle(PocketTheme.accent) }
                if !isSelecting {
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(PocketTheme.muted)
                }
            }
            .padding(13)
            .background(isSelected || (!isSelecting && store.selectedItemID == item.id) ? PocketTheme.elevated : PocketTheme.card.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

private struct DetailColumn: View {
    @Environment(VaultStore.self) private var store
    var body: some View {
        VStack(spacing: 18) {
            SummaryCard()
            Group {
                if let item = store.selectedItem { ItemDetail(item: item) }
                else { ContentUnavailableView("选择账户", systemImage: "hand.tap", description: Text("选择一个账户以查看详细信息")) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(22).pocketPanel()
        }
    }
}

private struct SummaryCard: View {
    @Environment(VaultStore.self) private var store
    @State private var showingPasswordGenerator = false
    var activeCount: Int { store.items.filter { $0.deletedAt == nil }.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("总览").font(.headline)
                Spacer()
                Button { showingPasswordGenerator = true } label: {
                    Label("生成密码", systemImage: "wand.and.stars")
                        .font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 7)
                        .background(PocketTheme.inset).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                Stat(icon: "key.fill", value: "\(activeCount)", title: "账户")
                Stat(icon: "square.grid.2x2.fill", value: "\(store.categories.count)", title: "分类")
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [PocketTheme.accent.opacity(0.52), PocketTheme.accentDeep.opacity(0.20)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .sheet(isPresented: $showingPasswordGenerator) { PasswordGeneratorView() }
    }
}

private struct Stat: View {
    let icon: String; let value: String; let title: String
    var body: some View {
        HStack { Image(systemName: icon).foregroundStyle(PocketTheme.accent); Text(value).bold(); Text(LocalizedStringKey(title)).foregroundStyle(PocketTheme.muted) }
            .frame(maxWidth: .infinity).padding(12).background(PocketTheme.inset).clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

private struct ItemDetail: View {
    @Environment(VaultStore.self) private var store
    let item: VaultItem
    @State private var revealPassword = false
    @State private var showingEdit = false
    @State private var confirmingTrash = false
    @State private var confirmingPermanentDelete = false
    @State private var copiedFieldName: String?

    private var categoryName: String {
        store.categories.first(where: { $0.id == item.categoryID })?.name ?? "未分类"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 15) {
                    VaultIconView(symbol: item.symbol, data: item.iconData, size: 60, cornerRadius: 17)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.name).font(.headline.bold())
                        Text(LocalizedStringKey(categoryName)).font(.callout).foregroundStyle(PocketTheme.muted)
                    }
                    Spacer()
                }

                if item.deletedAt == nil {
                    HStack(spacing: 12) {
                        Button { showingEdit = true } label: {
                            Label("编辑", systemImage: "pencil")
                                .font(.body.weight(.semibold))
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(PocketTheme.inset)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button { confirmingTrash = true } label: {
                            Label("删除", systemImage: "trash")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(PocketTheme.inset)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 12) {
                        Button { store.restore(item.id) } label: {
                            Label("恢复账户", systemImage: "arrow.uturn.backward")
                                .font(.body.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 9)
                                .background(PocketTheme.inset).clipShape(Capsule())
                        }.buttonStyle(.plain)
                        Button { confirmingPermanentDelete = true } label: {
                            Label("永久删除", systemImage: "trash.slash")
                                .font(.body.weight(.semibold)).foregroundStyle(.red)
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(PocketTheme.inset).clipShape(Capsule())
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                }

                ForEach(Array(item.accounts.enumerated()), id: \.element.id) { index, account in
                    Text(item.accounts.count > 1 ? "账户 \(index + 1)" : "账户")
                        .font(.callout.weight(.semibold)).foregroundStyle(PocketTheme.muted)
                        .padding(.top, 4)
                    VStack(spacing: 12) {
                        DetailField(
                            label: "用户名",
                            value: account.username,
                            secret: false,
                            reveal: true,
                            onCopy: showCopyNotice
                        )
                        DetailField(
                            label: "密码",
                            value: account.password,
                            secret: true,
                            reveal: revealPassword,
                            toggleReveal: { revealPassword.toggle() },
                            onCopy: showCopyNotice
                        )
                        ForEach(account.fields) { field in
                            DetailField(
                                label: field.name,
                                value: field.value,
                                secret: field.isSecret,
                                reveal: !field.isSecret,
                                onCopy: showCopyNotice
                            )
                        }
                    }
                }

                if store.selectedSection != .home && (!item.website.isEmpty || !item.tags.isEmpty || !item.note.isEmpty) {
                    Text("其他信息").font(.headline).foregroundStyle(PocketTheme.muted).padding(.top, 4)
                    VStack(spacing: 12) {
                        if !item.website.isEmpty {
                            DetailField(
                                label: "网址",
                                value: item.website,
                                secret: false,
                                reveal: true,
                                onCopy: showCopyNotice
                            )
                        }
                        if !item.tags.isEmpty {
                            DetailInfoCard(label: "标签", value: item.tags.map { "#\($0)" }.joined(separator: "   "), accent: true)
                        }
                        if !item.note.isEmpty {
                            DetailInfoCard(label: "备注", value: item.note)
                        }
                    }
                }

                if store.selectedSection != .home, let attachments = item.attachments, !attachments.isEmpty {
                    Text("图片").font(.headline).foregroundStyle(PocketTheme.muted).padding(.top, 4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(attachments) { attachment in
                                if let image = NSImage(data: attachment.data) {
                                    Image(nsImage: image).resizable().scaledToFill().frame(width: 110, height: 78)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .overlay(alignment: .bottom) {
            if let copiedFieldName {
                Text("已复制\(copiedFieldName)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(.black.opacity(0.82))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .task(id: copiedFieldName) {
            guard let copiedFieldName else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard self.copiedFieldName == copiedFieldName else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.copiedFieldName = nil
            }
        }
        .sheet(isPresented: $showingEdit) { EditItemView(item: item) }
        .confirmationDialog("删除此账户？", isPresented: $confirmingTrash, titleVisibility: .visible) {
            Button("移到回收站", role: .destructive) { store.moveToTrash(item.id) }
            Button("取消", role: .cancel) { }
        } message: {
            Text("账户将在回收站保留 30 天，期间可以恢复。")
        }
        .confirmationDialog("永久删除此账户？", isPresented: $confirmingPermanentDelete, titleVisibility: .visible) {
            Button("永久删除", role: .destructive) { store.permanentlyDelete(item.id) }
            Button("取消", role: .cancel) { }
        } message: {
            Text("此操作无法撤销。")
        }
    }

    private func showCopyNotice(_ fieldName: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            copiedFieldName = fieldName
        }
    }
}

private struct DetailField: View {
    let label: String; let value: String; let secret: Bool; let reveal: Bool
    var toggleReveal: (() -> Void)? = nil
    var onCopy: ((String) -> Void)? = nil

    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 7) {
                Text(LocalizedStringKey(label)).font(.caption).foregroundStyle(PocketTheme.muted)
                Text(secret && !reveal ? String(repeating: "•", count: max(8, value.count)) : value)
                    .font(.body.monospaced())
                    .foregroundStyle(PocketTheme.primary.opacity(0.94))
                    .lineLimit(3)
            }
            Spacer()
            if secret, let toggleReveal {
                Button(action: toggleReveal) {
                    Image(systemName: reveal ? "eye.slash" : "eye")
                        .font(.body)
                        .frame(width: 30, height: 26)
                        .background(PocketTheme.controlFill).clipShape(Capsule())
                }
                .buttonStyle(.plain).foregroundStyle(PocketTheme.muted)
                .help(reveal ? "隐藏" : "显示")
            }
            Button {
                ClipboardManager.copy(value)
                onCopy?(label)
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 30, height: 26)
                    .background(PocketTheme.controlFill).clipShape(Capsule())
            }
                .font(.body).buttonStyle(.plain).foregroundStyle(PocketTheme.muted)
                .help("复制")
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .background(PocketTheme.inset)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct DetailInfoCard: View {
    let label: String
    let value: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(LocalizedStringKey(label)).font(.headline).foregroundStyle(PocketTheme.muted)
            Text(value)
                .font(.body)
                .foregroundStyle(accent ? PocketTheme.accent : PocketTheme.primary.opacity(0.85))
                .textSelection(.enabled)
        }
        .padding(.horizontal, 20).padding(.vertical, 17)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(PocketTheme.inset)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct LockOverlay: View {
    @Environment(VaultStore.self) private var store
    @State private var errorMessage = ""
    @State private var authenticating = false
    var body: some View {
        ZStack {
            PocketTheme.background.ignoresSafeArea()
            VStack(spacing: 14) {
                InterfaceBrandLogoView(size: 58)
                    .padding(.bottom, 8)
                Text("口袋密码已锁定")
                    .font(.title3.bold())
                Text("使用 Touch ID 或设备密码解锁")
                    .font(.callout)
                    .foregroundStyle(PocketTheme.muted)
                Button { authenticate() } label: {
                    HStack(spacing: 9) {
                        if authenticating { ProgressView().controlSize(.small) }
                        else { Image(systemName: "touchid") }
                        Text(authenticating ? "正在验证…" : "使用 Touch ID 或设备密码解锁")
                    }
                    .font(.callout.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                }
                .buttonStyle(.plain)
                .background(PocketTheme.accent)
                .foregroundStyle(.black)
                .clipShape(Capsule())
                .disabled(authenticating)
                .padding(.top, 12)
                if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundStyle(.red) }
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 50)
        }
        .task { authenticate() }
    }

    private func authenticate() {
        guard !authenticating else { return }
        authenticating = true
        errorMessage = ""
        Task {
            do {
                try await store.appLockService.authenticate(language: store.appLanguage)
                store.showingLockScreen = false
            } catch {
                errorMessage = store.appLanguage.text(
                    "验证未完成，请使用 Touch ID 或设备密码重试",
                    "Authentication was not completed. Try Touch ID or your Mac password again."
                )
            }
            authenticating = false
        }
    }
}
