import SwiftUI

struct TagManagementView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editingTag: String?
    @State private var newName = ""
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("标签管理").font(.title2.bold()); Spacer(); Button("完成") { dismiss() }.buttonStyle(.bordered) }
            HStack(spacing: 10) {
                TextField("新建可复用标签", text: $newTag)
                    .textFieldStyle(.plain).padding(.horizontal, 14).padding(.vertical, 10)
                    .background(PocketTheme.card).clipShape(Capsule())
                    .onSubmit { addTag() }
                Button("添加") { addTag() }
                    .buttonStyle(.borderedProminent).tint(PocketTheme.accent).foregroundStyle(.black)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if store.allTags.isEmpty {
                ContentUnavailableView("暂无标签", systemImage: "tag", description: Text("可在上方新建，供所有账户共同使用"))
            } else {
                ForEach(store.allTags, id: \.self) { tag in
                    HStack {
                        Image(systemName: "tag.fill").foregroundStyle(PocketTheme.accent)
                        if editingTag == tag {
                            TextField("标签名称", text: $newName).textFieldStyle(.roundedBorder)
                            Button("保存") { store.renameTag(tag, to: newName); editingTag = nil }.buttonStyle(.bordered)
                        } else {
                            Text(tag); Spacer()
                            Button { editingTag = tag; newName = tag } label: {
                                Image(systemName: "pencil").frame(width: 32, height: 26)
                                    .background(.white.opacity(0.05)).clipShape(Capsule())
                            }.buttonStyle(.plain)
                            Button(role: .destructive) { store.deleteTag(tag) } label: {
                                Image(systemName: "trash").frame(width: 32, height: 26)
                                    .background(.red.opacity(0.08)).clipShape(Capsule())
                            }.buttonStyle(.plain)
                        }
                    }.padding(12).background(PocketTheme.card).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }.padding(24).frame(width: 460, height: 420).background(PocketTheme.background)
            .buttonBorderShape(.capsule)
    }

    private func addTag() {
        store.addTag(newTag)
        newTag = ""
    }
}
