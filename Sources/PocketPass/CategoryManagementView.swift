import SwiftUI

struct CategoryManagementView: View {
    @Environment(VaultStore.self) private var store
    @State private var selectedCategoryID: UUID?
    @State private var searchText = ""
    @State private var editingCategory: VaultCategory?
    @State private var confirmingDelete = false
    @State private var dropTargetID: UUID?

    private var selectedCategory: VaultCategory? {
        store.categories.first { $0.id == selectedCategoryID }
    }

    private var categoryItems: [VaultItem] {
        guard let selectedCategoryID else { return [] }
        return store.items.filter {
            $0.categoryID == selectedCategoryID && $0.deletedAt == nil &&
            (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("分类").font(.title2.bold())
                        Text("按住分类卡片可拖动排序").font(.caption).foregroundStyle(PocketTheme.muted)
                    }
                    Spacer()
                    Button { store.showingAddCategory = true } label: {
                        Image(systemName: "plus").font(.headline.bold()).frame(width: 38, height: 38)
                            .background(PocketTheme.card).clipShape(Capsule())
                    }.buttonStyle(.plain).help("添加分类")
                }

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                        spacing: 10
                    ) {
                        ForEach(store.categories) { category in
                            CategoryCard(category: category,
                                         count: store.items.filter { $0.categoryID == category.id && $0.deletedAt == nil }.count,
                                         selected: selectedCategoryID == category.id,
                                         isDropTarget: dropTargetID == category.id) {
                                selectedCategoryID = category.id
                            }
                            .draggable(category.id.uuidString) {
                                CategoryDragPreview(category: category)
                            }
                            .dropDestination(for: String.self) { values, _ in
                                guard let rawID = values.first, let sourceID = UUID(uuidString: rawID) else { return false }
                                withAnimation(.smooth(duration: 0.22)) {
                                    store.moveCategory(sourceID, to: category.id)
                                }
                                dropTargetID = nil
                                return true
                            } isTargeted: { targeted in
                                dropTargetID = targeted ? category.id : (dropTargetID == category.id ? nil : dropTargetID)
                            }
                            .help("按住并拖动以调整分类顺序")
                        }
                    }
                    .padding(.trailing, 8)
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(24).frame(minWidth: 570).pocketPanel()

            VStack(spacing: 18) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(PocketTheme.muted)
                    TextField("搜索", text: $searchText).textFieldStyle(.plain)
                }.padding(13).background(PocketTheme.panel).clipShape(RoundedRectangle(cornerRadius: 18))

                if let category = selectedCategory {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            CategoryIconView(symbol: category.icon, data: category.iconData, color: category.color)
                            VStack(alignment: .leading) {
                                Text(LocalizedStringKey(category.name)).font(.title3.bold())
                                Text("\(categoryItems.count) 个账户").font(.caption).foregroundStyle(PocketTheme.muted)
                            }
                            Spacer()
                            Button { editingCategory = category } label: {
                                Image(systemName: "square.and.pencil").frame(width: 34, height: 28)
                                    .background(PocketTheme.card).clipShape(Capsule())
                            }.buttonStyle(.plain)
                            Button(role: .destructive) { confirmingDelete = true } label: {
                                Image(systemName: "trash").frame(width: 34, height: 28)
                                    .background(.red.opacity(0.08)).clipShape(Capsule())
                            }.buttonStyle(.plain).disabled(store.categories.count <= 1)
                        }
                        if categoryItems.isEmpty {
                            ContentUnavailableView("暂无账户", systemImage: category.icon, description: Text("此分类下还没有账户"))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView(.vertical, showsIndicators: true) {
                                LazyVStack(spacing: 10) {
                                    ForEach(categoryItems) { item in
                                        Button {
                                            store.selectedItemID = item.id
                                            store.selectedSection = .home
                                        } label: {
                                            HStack {
                                                VaultIconView(symbol: item.symbol, data: item.iconData, size: 34, cornerRadius: 9)
                                                Text(item.name).font(.headline)
                                                Spacer(); Image(systemName: "chevron.right").font(.caption)
                                            }.padding(11).background(PocketTheme.card).clipShape(RoundedRectangle(cornerRadius: 13))
                                        }.buttonStyle(.plain)
                                    }
                                }
                                .padding(.trailing, 6)
                                .padding(.bottom, 8)
                            }
                        }
                    }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity).pocketPanel()
                } else {
                    ContentUnavailableView("选择分类", systemImage: "hand.tap", description: Text("选择一个分类以查看账户"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity).pocketPanel()
                }
            }.frame(minWidth: 350, maxWidth: 430)
        }
        .sheet(item: $editingCategory) { EditCategoryView(category: $0) }
        .confirmationDialog("删除此分类？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除分类", role: .destructive) {
                if let selectedCategoryID { store.deleteCategory(selectedCategoryID); self.selectedCategoryID = nil }
            }
            Button("取消", role: .cancel) { }
        } message: { Text("分类内账户将自动转移到“其他”或现有分类。") }
    }
}

private struct CategoryCard: View {
    let category: VaultCategory
    let count: Int
    let selected: Bool
    let isDropTarget: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    CategoryIconView(
                        symbol: category.icon,
                        data: category.iconData,
                        color: .white.opacity(0.2),
                        size: 28,
                        cornerRadius: 8
                    )
                    Spacer(); Text("\(count)").font(.caption.bold())
                }
                Text(LocalizedStringKey(category.name))
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(11).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(LinearGradient(colors: [category.color.opacity(0.9), category.color.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isDropTarget ? PocketTheme.accent : (selected ? .white : .clear), lineWidth: isDropTarget ? 3 : 2))
            .scaleEffect(isDropTarget ? 1.035 : 1)
        }.buttonStyle(.plain)
    }
}

private struct CategoryDragPreview: View {
    let category: VaultCategory

    var body: some View {
        HStack(spacing: 9) {
            CategoryIconView(symbol: category.icon, data: category.iconData, color: category.color, size: 30, cornerRadius: 8)
            Text(LocalizedStringKey(category.name)).font(.callout.bold())
        }
        .padding(.horizontal, 15).padding(.vertical, 11)
        .background(PocketTheme.elevated)
        .clipShape(Capsule())
    }
}
