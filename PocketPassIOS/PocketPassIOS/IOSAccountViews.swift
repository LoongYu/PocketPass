import PhotosUI
import SwiftUI

struct IOSAccountDetailView: View {
    let item: VaultItem
    @EnvironmentObject private var store: VaultStore
    @EnvironmentObject private var settings: IOSAppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var visiblePasswords: Set<UUID> = []
    @State private var copiedField: String?
    @State private var showEditor = false
    @State private var confirmDelete = false

    private var currentItem: VaultItem { store.items.first(where: { $0.id == item.id }) ?? item }
    private var categoryName: String { store.categories.first(where: { $0.id == currentItem.categoryID })?.name ?? "其他" }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                IOSTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 15) {
                            IOSVaultIcon(symbol: currentItem.symbol, data: currentItem.iconData, size: 68, background: IOSTheme.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(currentItem.name).font(.title2.bold())
                                Text(LocalizedStringKey(categoryName)).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        HStack(spacing: 10) {
                            capsuleButton("编辑", icon: "pencil") { showEditor = true }
                            capsuleButton("删除", icon: "trash", destructive: true) { confirmDelete = true }
                        }
                        ForEach(Array(currentItem.accounts.enumerated()), id: \.element.id) { index, account in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(currentItem.accounts.count == 1
                                     ? settings.language.text("账户", "Account")
                                     : settings.language.text("登录账号 \(index + 1)", "Login \(index + 1)"))
                                    .font(.headline).foregroundStyle(index == 0 ? IOSTheme.accent : .secondary)
                                detailField("用户名", value: account.username)
                                detailField("密码", value: visiblePasswords.contains(account.id) ? account.password : String(repeating: "•", count: min(10, max(1, account.password.count))), secretAccount: account)
                                ForEach(account.fields) { field in
                                    detailField(field.name, value: field.isSecret ? String(repeating: "•", count: min(10, max(1, field.value.count))) : field.value, copyValue: field.value)
                                }
                            }
                        }
                    }
                    .padding(20).padding(.bottom, 42)
                }
                if let copiedField {
                    Text(settings.language.text("已复制\(copiedField)", "Copied \(copiedField)")).font(.subheadline.bold())
                        .padding(.horizontal, 18).padding(.vertical, 11)
                        .background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.fontWeight(.semibold) } }
            .sheet(isPresented: $showEditor) { IOSAccountEditorView(item: currentItem) }
            .confirmationDialog("移到回收站？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("移到回收站", role: .destructive) { store.moveToTrash([currentItem.id]); dismiss() }
                Button("取消", role: .cancel) {}
            } message: { Text("删除后保留 30 天，期间可在回收站恢复。") }
        }
        .presentationDetents([.large])
    }

    private func capsuleButton(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { Text(LocalizedStringKey(title)) } icon: { Image(systemName: icon) }
                .font(.subheadline.bold()).foregroundStyle(destructive ? .red : .primary)
                .padding(.horizontal, 16).padding(.vertical, 11).background(IOSTheme.panel, in: Capsule())
        }.buttonStyle(.plain)
    }

    private func detailField(_ title: String, value: String, copyValue: String? = nil, secretAccount: LoginAccount? = nil) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(LocalizedStringKey(title)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(value).font(.body.weight(.medium)).textSelection(.enabled)
            }
            Spacer()
            if let secretAccount {
                Button {
                    if visiblePasswords.contains(secretAccount.id) { visiblePasswords.remove(secretAccount.id) } else { visiblePasswords.insert(secretAccount.id) }
                } label: { Image(systemName: visiblePasswords.contains(secretAccount.id) ? "eye.slash" : "eye") }.buttonStyle(.plain)
            }
            Button {
                IOSClipboardManager.copy(copyValue ?? secretAccount?.password ?? value)
                withAnimation { copiedField = title }
                Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { copiedField = nil } }
            } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain)
        }
        .padding(18).iosPanel(radius: 20)
    }
}

struct IOSAccountEditorView: View {
    @EnvironmentObject private var store: VaultStore
    @EnvironmentObject private var settings: IOSAppSettings
    @Environment(\.dismiss) private var dismiss
    let item: VaultItem?
    @State private var name: String
    @State private var categoryID: UUID?
    @State private var accounts: [LoginAccount]
    @State private var selectedTags: Set<String>
    @State private var note: String
    @State private var symbol: String
    @State private var iconData: Data?
    @State private var attachments: [ImageAttachment]
    @State private var showIconPicker = false
    @State private var showTagPicker = false
    @State private var showGenerator = false
    @State private var generatorTarget = 0
    @State private var fieldTarget = 0
    @State private var showFieldPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var validationMessage: String?

    init(item: VaultItem? = nil) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _categoryID = State(initialValue: item?.categoryID)
        _accounts = State(initialValue: item?.accounts.isEmpty == false ? item!.accounts : [LoginAccount(username: "", password: "")])
        _selectedTags = State(initialValue: Set(item?.tags ?? []))
        _note = State(initialValue: item?.note ?? "")
        _symbol = State(initialValue: item?.symbol ?? "person.fill")
        _iconData = State(initialValue: item?.iconData)
        _attachments = State(initialValue: item?.attachments ?? [])
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IOSTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        Button { showIconPicker = true } label: {
                            VStack(spacing: 9) {
                                IOSVaultIcon(symbol: symbol, data: iconData, size: 72, background: IOSTheme.accent)
                                Text("图标选择").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 18).iosPanel(radius: 22)
                        }.buttonStyle(.plain)

                        VStack(spacing: 10) {
                            inputField("名称", text: $name)
                            Picker("分类", selection: Binding(get: { categoryID ?? store.categories.first?.id }, set: { categoryID = $0 })) {
                                ForEach(store.categories) { Text(LocalizedStringKey($0.name)).tag(Optional($0.id)) }
                            }
                            .pickerStyle(.menu).frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                            .padding(.horizontal, 16).background(IOSTheme.input, in: RoundedRectangle(cornerRadius: 17))
                            Button { showTagPicker = true } label: {
                                HStack {
                                    Text(selectedTags.isEmpty ? "标签" : selectedTags.sorted().joined(separator: "、")).foregroundStyle(selectedTags.isEmpty ? .secondary : .primary)
                                    Spacer(); Image(systemName: "tag")
                                }
                                .padding(.horizontal, 16).frame(minHeight: 50).background(IOSTheme.input, in: RoundedRectangle(cornerRadius: 17))
                            }.buttonStyle(.plain)
                        }
                        .padding(12).iosPanel(radius: 22)

                        ForEach(Array(accounts.indices), id: \.self) { index in loginEditor(index) }

                        Button { accounts.append(LoginAccount(username: "", password: "")) } label: {
                            Label("添加账号", systemImage: "person.badge.plus").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 15)
                        }.buttonStyle(.plain).iosPanel(radius: 22)

                        TextField("备注（可选）", text: $note, axis: .vertical).lineLimit(4, reservesSpace: true).padding(16)
                            .background(IOSTheme.input, in: RoundedRectangle(cornerRadius: 18)).padding(12).iosPanel(radius: 22)

                        VStack(spacing: 10) {
                            if !attachments.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(attachments) { attachment in
                                            if let image = UIImage(data: attachment.data) {
                                                Image(uiImage: image).resizable().scaledToFill().frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 14))
                                                    .contextMenu { Button("删除", role: .destructive) { attachments.removeAll { $0.id == attachment.id } } }
                                            }
                                        }
                                    }
                                }
                            }
                            Text("已选 \(attachments.count)/5 张")
                                .font(.caption).foregroundStyle(.secondary)
                            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: max(1, 5 - attachments.count), matching: .images) {
                                Label("添加图片", systemImage: "photo.badge.plus").frame(maxWidth: .infinity).padding(.vertical, 15)
                            }.buttonStyle(.plain)
                        }.padding(12).iosPanel(radius: 22)
                    }.padding(18)
                }
            }
            .navigationTitle(Text(LocalizedStringKey(item == nil ? "添加账户" : "编辑账户"))).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.fontWeight(.bold).foregroundStyle(canSave ? .black : .secondary)
                        .padding(.horizontal, 14).padding(.vertical, 8).background(canSave ? IOSTheme.accent : Color.secondary.opacity(0.15), in: Capsule()).disabled(!canSave)
                }
            }
            .sheet(isPresented: $showIconPicker) { IOSIconPickerView(symbol: $symbol, iconData: $iconData) }
            .sheet(isPresented: $showTagPicker) { IOSTagPickerView(selection: $selectedTags) }
            .sheet(isPresented: $showFieldPicker) {
                IOSFieldTemplatePickerView { fieldName, secret in
                    guard accounts.indices.contains(fieldTarget) else { return }
                    accounts[fieldTarget].fields.append(CustomField(name: fieldName, value: "", isSecret: secret))
                }
            }
            .sheet(isPresented: $showGenerator) {
                IOSPasswordGeneratorView { generated in
                    if accounts.indices.contains(generatorTarget) { accounts[generatorTarget].password = generated }
                    showGenerator = false
                }
            }
            .onChange(of: selectedPhotos) { _, photos in Task { await addAttachments(photos) } }
            .alert("无法添加图片", isPresented: Binding(get: { validationMessage != nil }, set: { if !$0 { validationMessage = nil } })) {
                Button("好") { validationMessage = nil }
            } message: { Text(validationMessage ?? "") }
        }
    }

    private func loginEditor(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(accounts.count == 1 ? "登录账号" : "登录账号 \(index + 1)").font(.headline).foregroundStyle(IOSTheme.accent)
                Spacer()
                if accounts.count > 1 { Button(role: .destructive) { accounts.remove(at: index) } label: { Image(systemName: "minus.circle.fill") } }
            }
            inputField("用户名 / 手机号 / 邮箱", text: $accounts[index].username)
            HStack {
                SecureField("密码", text: $accounts[index].password)
                Button { generatorTarget = index; showGenerator = true } label: { Image(systemName: "dice.fill") }.accessibilityLabel("生成密码")
            }.padding(.horizontal, 16).frame(minHeight: 50).background(IOSTheme.input, in: RoundedRectangle(cornerRadius: 17))
            ForEach(Array(accounts[index].fields.indices), id: \.self) { fieldIndex in
                HStack(spacing: 8) {
                    TextField("字段名", text: $accounts[index].fields[fieldIndex].name).frame(width: 108)
                    Divider().frame(height: 24)
                    if accounts[index].fields[fieldIndex].isSecret { SecureField("字段内容", text: $accounts[index].fields[fieldIndex].value) }
                    else { TextField("字段内容", text: $accounts[index].fields[fieldIndex].value) }
                    Button(role: .destructive) { accounts[index].fields.remove(at: fieldIndex) } label: { Image(systemName: "minus.circle.fill") }
                }.padding(.horizontal, 14).frame(minHeight: 50).background(IOSTheme.input, in: RoundedRectangle(cornerRadius: 17))
            }
            Button { fieldTarget = index; showFieldPicker = true } label: {
                Label("添加字段", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 14)
            }.buttonStyle(.plain).background(IOSTheme.input, in: Capsule())
        }.padding(12).iosPanel(radius: 22)
    }

    private func inputField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text).padding(.horizontal, 16).frame(minHeight: 50).background(IOSTheme.input, in: RoundedRectangle(cornerRadius: 17))
    }

    private func save() {
        guard let resolvedCategoryID = categoryID ?? store.categories.first?.id else { return }
        let website = accounts.flatMap(\.fields).first(where: { $0.name == "网址" })?.value ?? item?.website ?? ""
        if var updated = item {
            updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines); updated.categoryID = resolvedCategoryID; updated.accounts = accounts
            updated.tags = selectedTags.sorted(); updated.note = note; updated.symbol = symbol; updated.iconData = iconData
            updated.attachments = attachments; updated.website = website; store.updateItem(updated)
        } else {
            store.addItem(name: name.trimmingCharacters(in: .whitespacesAndNewlines), accounts: accounts, tags: selectedTags.sorted(), website: website, categoryID: resolvedCategoryID, note: note, symbol: symbol, iconData: iconData, attachments: attachments)
        }
        dismiss()
    }

    @MainActor private func addAttachments(_ photos: [PhotosPickerItem]) async {
        for (offset, photo) in photos.enumerated() where attachments.count < 5 {
            guard let data = try? await photo.loadTransferable(type: Data.self), data.count <= 2_000_000 else {
                validationMessage = settings.language.text(
                    "单张图片需小于 2 MB，每个账户最多 5 张。",
                    "Each image must be under 2 MB, with up to 5 images per item."
                ); continue
            }
            attachments.append(ImageAttachment(filename: "attachment-\(attachments.count + offset + 1).jpg", data: data))
        }
        selectedPhotos = []
    }
}

struct IOSTagPickerView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Set<String>
    @State private var newTag = ""
    var body: some View {
        NavigationStack {
            List {
                Section { HStack { TextField("新建标签", text: $newTag); Button("添加") { store.addTag(newTag); selection.insert(newTag.trimmingCharacters(in: .whitespacesAndNewlines)); newTag = "" }.disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
                Section { ForEach(store.tags, id: \.self) { tag in Button { if selection.contains(tag) { selection.remove(tag) } else { selection.insert(tag) } } label: { HStack { Label(tag, systemImage: "tag.fill"); Spacer(); if selection.contains(tag) { Image(systemName: "checkmark") } } } } }
            }.navigationTitle("选择标签").toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.fontWeight(.bold) } }
        }
    }
}

struct IOSFieldTemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String, Bool) -> Void
    @State private var customName = ""
    @State private var showCustom = false
    private let templates: [(String, String, Bool)] = [("账户", "person.crop.circle", false), ("密码", "key.fill", true), ("手机号", "phone.fill", false), ("邮箱", "envelope.fill", false), ("ID", "number", false), ("昵称", "person.fill", false), ("注册时间", "calendar", false), ("网址", "globe", false)]
    var body: some View {
        NavigationStack {
            List {
                ForEach(templates, id: \.0) { template in
                    Button { onSelect(template.0, template.2); dismiss() } label: {
                        Label { Text(LocalizedStringKey(template.0)) } icon: { Image(systemName: template.1) }
                    }
                }
                Button { showCustom = true } label: { Label("自定义", systemImage: "plus.circle") }
            }.navigationTitle("添加字段").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .alert("自定义字段", isPresented: $showCustom) { TextField("字段名称", text: $customName); Button("取消", role: .cancel) {}; Button("添加") { onSelect(customName, false); dismiss() }.disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
    }
}

struct IOSPasswordGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var length = 18.0
    @State private var includeUppercase = true
    @State private var includeNumbers = true
    @State private var includeSymbols = true
    @State private var password = ""
    var onUse: ((String) -> Void)?
    var body: some View {
        NavigationStack {
            ZStack {
                IOSTheme.background.ignoresSafeArea()
                VStack(spacing: 18) {
                    VStack(spacing: 14) { Text(password).font(.system(.title3, design: .monospaced, weight: .bold)).textSelection(.enabled).frame(maxWidth: .infinity, minHeight: 90); Button("重新生成") { generate() }.fontWeight(.bold).foregroundStyle(.black).padding(.horizontal, 18).padding(.vertical, 11).background(IOSTheme.accent, in: Capsule()) }.padding(20).iosPanel()
                    VStack(spacing: 14) { HStack { Text("长度"); Spacer(); Text("\(Int(length))").monospacedDigit() }; Slider(value: $length, in: 8...64, step: 1); Toggle("大写字母", isOn: $includeUppercase); Toggle("数字", isOn: $includeNumbers); Toggle("符号", isOn: $includeSymbols) }.padding(20).iosPanel(); Spacer()
                }.padding(18)
            }.navigationTitle("生成密码").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("使用") { onUse?(password); if onUse == nil { IOSClipboardManager.copy(password) }; dismiss() }.fontWeight(.bold) } }
            .onAppear { generate() }.onChange(of: length) { _, _ in generate() }.onChange(of: includeUppercase) { _, _ in generate() }.onChange(of: includeNumbers) { _, _ in generate() }.onChange(of: includeSymbols) { _, _ in generate() }
        }.presentationDetents([.large])
    }
    private func generate() { password = PasswordGenerator.generate(length: Int(length), includeUppercase: includeUppercase, includeNumbers: includeNumbers, includeSymbols: includeSymbols) }
}
