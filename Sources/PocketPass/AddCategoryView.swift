import SwiftUI

struct AddCategoryView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedIconData: Data?
    @State private var selectedColor = Color(hex: "F59E0B")
    @State private var usesCustomColor = false
    @State private var showingIconPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                InterfaceBrandLogoView(size: 21)
                Text("添加分类").font(.title3.bold())
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("添加") { addCategory() }.buttonStyle(.borderedProminent)
                    .tint(PocketTheme.accent).foregroundStyle(.black)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(22)
            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    Button { showingIconPicker = true } label: {
                        VStack(spacing: 7) {
                            CategoryIconView(
                                symbol: selectedIcon,
                                data: selectedIconData,
                                color: selectedColor,
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
                CategoryColorPalette(color: $selectedColor, usesCustomColor: $usesCustomColor)
            }
            .padding(24)
            Spacer()
        }
        .frame(width: 560, height: 420)
        .background(PocketTheme.background)
        .buttonBorderShape(.capsule)
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon, selectedIconData: $selectedIconData)
        }
    }

    private func addCategory() {
        store.addCategory(
            name: name.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            iconData: selectedIconData,
            colorHex: selectedColor.hexRGB
        )
        dismiss()
    }
}
