import SwiftUI

struct EditCategoryView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: VaultCategory
    @State private var name: String
    @State private var icon: String
    @State private var iconData: Data?
    @State private var color: Color
    @State private var usesCustomColor: Bool
    @State private var showingIconPicker = false

    init(category: VaultCategory) {
        original = category
        _name = State(initialValue: category.name)
        _icon = State(initialValue: category.icon)
        _iconData = State(initialValue: category.iconData)
        _color = State(initialValue: category.color)
        _usesCustomColor = State(
            initialValue: !CategoryColorPalette.presetHexes.contains(category.colorHex.uppercased())
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                InterfaceBrandLogoView(size: 21)
                Text("编辑分类").font(.title3.bold())
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("保存") { save() }.buttonStyle(.borderedProminent)
                    .tint(PocketTheme.primaryButton).foregroundStyle(PocketTheme.primaryButtonText)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(22)
            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    Button { showingIconPicker = true } label: {
                        VStack(spacing: 7) {
                            CategoryIconView(
                                symbol: icon,
                                data: iconData,
                                color: color,
                                size: 66,
                                cornerRadius: 18
                            )
                            Text("图标选择").font(.caption).foregroundStyle(PocketTheme.muted)
                        }
                    }
                    .buttonStyle(.plain)

                    TextField("分类名称", text: $name)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 15).padding(.vertical, 13)
                        .background(PocketTheme.input)
                        .clipShape(Capsule())
                }

                Text("颜色").font(.caption.bold()).foregroundStyle(PocketTheme.muted)
                CategoryColorPalette(color: $color, usesCustomColor: $usesCustomColor)
            }
            .padding(24)
            Spacer()
        }
        .frame(width: 560, height: 420)
        .background(PocketTheme.background)
        .buttonBorderShape(.capsule)
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $icon, selectedIconData: $iconData)
        }
    }

    private func save() {
        var category = original
        category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        category.icon = icon
        category.iconData = iconData
        category.colorHex = color.hexRGB
        store.updateCategory(category)
        dismiss()
    }
}
