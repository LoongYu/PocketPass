import SwiftUI
import UniformTypeIdentifiers

struct AddItemView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var accounts = [LoginAccount(id: UUID(), username: "", password: "", fields: [])]
    @State private var selectedTags: [String] = []
    @State private var note = ""
    @State private var categoryID: UUID?
    @State private var selectedIcon = "message.fill"
    @State private var selectedIconData: Data?
    @State private var showingIconPicker = false
    @State private var attachments: [ImageAttachment] = []
    @State private var showingImageImporter = false
    @State private var attachmentError = ""
    @State private var showingTagPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                InterfaceBrandLogoView()
                Text("添加账户").font(.title2.bold())
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.plain).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(PocketTheme.card).clipShape(Capsule())
                Button("保存") { save() }
                    .buttonStyle(.plain).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(PocketTheme.primaryButton).foregroundStyle(PocketTheme.primaryButtonText).clipShape(Capsule())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(.horizontal, 22).padding(.vertical, 14)
            Divider().opacity(0.25)

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 10) {
                        Button { showingIconPicker = true } label: {
                            VStack(spacing: 6) {
                                VaultIconView(symbol: selectedIcon, data: selectedIconData, size: 52, cornerRadius: 15)
                                Text("图标选择").font(.caption).foregroundStyle(PocketTheme.muted)
                            }.frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.plain)
                            .background(PocketTheme.card).clipShape(RoundedRectangle(cornerRadius: 18))

                        FormCard {
                            PlainInputRow {
                                TextField("名称", text: $name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(PocketTheme.primary)
                            }
                            PlainInputRow {
                                CategoryDropdown(selection: $categoryID)
                            }
                            PlainInputRow {
                                Button { showingTagPicker = true } label: {
                                    HStack {
                                        Text(selectedTags.isEmpty ? "标签" : selectedTags.joined(separator: "、"))
                                            .foregroundStyle(selectedTags.isEmpty ? PocketTheme.muted : PocketTheme.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "tag")
                                    }
                                }.buttonStyle(.plain)
                            }
                        }

                        FormCard {
                            NoteInputRow(text: $note, placeholder: "备注（可选）")
                        }

                        if !attachments.isEmpty {
                            AttachmentStrip(attachments: $attachments)
                        }
                        Button { showingImageImporter = true } label: {
                            Text("添加图片").frame(maxWidth: .infinity)
                        }.buttonStyle(.plain).padding(10).background(PocketTheme.card)
                            .clipShape(Capsule()).disabled(attachments.count >= 5)
                        if !attachmentError.isEmpty { Text(attachmentError).font(.caption).foregroundStyle(.red) }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 10) {
                        ForEach(Array(accounts.indices), id: \.self) { index in
                            LoginAccountEditor(account: $accounts[index], number: index + 1,
                                               canDelete: accounts.count > 1) {
                                accounts.remove(at: index)
                            }
                        }

                        Button {
                            accounts.append(.init(id: UUID(), username: "", password: "", fields: []))
                        } label: {
                            Text("添加账号")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.plain).padding(10).background(PocketTheme.card)
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }.padding(16)
            }
        }
        .frame(width: 800, height: 600).background(PocketTheme.background)
        .buttonBorderShape(.capsule)
        .onAppear { categoryID = categoryID ?? store.categories.first?.id }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon, selectedIconData: $selectedIconData)
        }
        .sheet(isPresented: $showingTagPicker) {
            TagPickerView(selectedTags: $selectedTags)
        }
        .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            attachmentError = ""
            for url in urls.prefix(5 - attachments.count) {
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url), data.count <= 5_000_000 else {
                    attachmentError = "已跳过无法读取或超过5 MB的图片"; continue
                }
                attachments.append(.init(id: UUID(), filename: url.lastPathComponent, data: data))
            }
        }
    }

    private func save() {
        guard let categoryID else { return }
        store.addItem(name: name, accounts: accounts, tags: selectedTags, website: "",
                      categoryID: categoryID, note: note, symbol: selectedIcon, iconData: selectedIconData, attachments: attachments)
        dismiss()
    }
}

struct AttachmentStrip: View {
    @Binding var attachments: [ImageAttachment]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        if let image = NSImage(data: attachment.data) {
                            Image(nsImage: image).resizable().scaledToFill().frame(width: 72, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button { attachments.removeAll { $0.id == attachment.id } } label: {
                            Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.75))
                        }.buttonStyle(.plain).offset(x: 5, y: -5)
                    }
                }
            }.padding(6)
        }
    }
}

struct LoginAccountEditor: View {
    @Binding var account: LoginAccount
    let number: Int
    let canDelete: Bool
    let onDelete: () -> Void
    @State private var revealPassword = false
    @State private var showingFieldPicker = false
    @State private var showingPasswordGenerator = false

    var body: some View {
        FormCard {
            if canDelete {
                HStack {
                    Text("账号 \(number)").font(.caption.bold()).foregroundStyle(PocketTheme.muted)
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash").frame(width: 32, height: 26)
                            .background(.red.opacity(0.08)).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
            PlainInputRow {
                TextField("用户名 / 手机号", text: $account.username)
            }
            PlainInputRow {
                HStack {
                    Group {
                        if revealPassword { TextField("密码", text: $account.password) }
                        else { SecureField("密码", text: $account.password) }
                    }.textFieldStyle(.plain)
                    Button { revealPassword.toggle() } label: {
                        Image(systemName: revealPassword ? "eye.slash" : "eye")
                            .frame(width: 28, height: 24).background(PocketTheme.controlFill).clipShape(Capsule())
                    }.buttonStyle(.plain)
                    Button { showingPasswordGenerator = true } label: {
                        Image(systemName: "die.face.5.fill")
                            .frame(width: 28, height: 24).background(PocketTheme.controlFill).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("生成密码")
                }
            }
            ForEach($account.fields) { $field in
                CustomFieldInputRow(field: $field) {
                    account.fields.removeAll { $0.id == field.id }
                }
            }
            Button {
                showingFieldPicker = true
            } label: {
                Label("添加字段", systemImage: "plus").frame(maxWidth: .infinity)
            }.buttonStyle(.plain).padding(10).background(PocketTheme.input)
                .clipShape(Capsule())
        }
        .sheet(isPresented: $showingFieldPicker) {
            AddFieldPickerView { name, isSecret in
                account.fields.append(.init(id: UUID(), name: name, value: "", isSecret: isSecret))
            }
        }
        .sheet(isPresented: $showingPasswordGenerator) {
            PasswordGeneratorView { generatedPassword in
                account.password = generatedPassword
                revealPassword = true
            }
        }
    }
}

private struct CustomFieldInputRow: View {
    @Binding var field: CustomField
    let onDelete: () -> Void
    @State private var revealSecret = false
    @State private var showingRename = false
    @State private var renameValue = ""

    var body: some View {
        PlainInputRow {
            HStack(spacing: 8) {
                Group {
                    if field.isSecret && !revealSecret {
                        SecureField(field.name, text: $field.value)
                    } else {
                        TextField(field.name, text: $field.value)
                    }
                }
                .textFieldStyle(.plain)

                if field.isSecret {
                    Button { revealSecret.toggle() } label: {
                        Image(systemName: revealSecret ? "eye.slash" : "eye")
                            .frame(width: 28, height: 24)
                            .background(PocketTheme.controlFill)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(revealSecret ? "隐藏" : "显示")
                }

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.body)
                        .frame(width: 28, height: 24)
                        .background(.red.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help("删除字段")
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("重命名字段") {
                renameValue = field.name
                showingRename = true
            }
            Button(field.isSecret ? "设为普通文本" : "设为密码") {
                field.isSecret.toggle()
                revealSecret = false
            }
            Divider()
            Button("删除字段", role: .destructive, action: onDelete)
        }
        .help("右键可重命名、修改格式或删除字段")
        .alert("重命名字段", isPresented: $showingRename) {
            TextField("字段名称", text: $renameValue)
            Button("取消", role: .cancel) { }
            Button("保存") {
                let trimmed = renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { field.name = trimmed }
            }
        }
    }
}

struct FormCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(PocketTheme.card).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct PlainInputRow<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(PocketTheme.input)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct CategoryDropdown: View {
    @Environment(VaultStore.self) private var store
    @Binding var selection: UUID?

    private var selectedName: String {
        store.categories.first(where: { $0.id == selection })?.name ?? "选择分类"
    }

    var body: some View {
        Menu {
            ForEach(store.categories) { category in
                Button {
                    selection = category.id
                } label: {
                    if selection == category.id {
                        Label(LocalizedStringKey(category.name), systemImage: "checkmark")
                    } else {
                        Text(LocalizedStringKey(category.name))
                    }
                }
            }
        } label: {
            HStack {
                Text(LocalizedStringKey(selectedName))
                    .font(.body.weight(.medium))
                    .foregroundStyle(PocketTheme.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PocketTheme.muted)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct NoteInputRow: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(LocalizedStringKey(placeholder)).foregroundStyle(PocketTheme.muted).padding(.top, 3)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(.body)
                .frame(height: 84)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(PocketTheme.input)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
