import SwiftUI

struct SettingsView: View {
    @Environment(VaultStore.self) private var store
    @State private var selection: SettingsSection = .security
    @State private var showingImport = false
    @State private var showingExport = false
    @State private var showingTags = false
    @State private var showingAbout = false
    @State private var showingPrivacy = false

    var body: some View {
        ScrollViewReader { proxy in
            HStack(alignment: .top, spacing: 18) {
                settingsSidebar(proxy: proxy)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        securitySection.id(SettingsSection.security)
                        cloudSection.id(SettingsSection.cloud)
                        generalSection.id(SettingsSection.general)
                        contentSection.id(SettingsSection.content)
                        dataSection.id(SettingsSection.data)
                        aboutSection.id(SettingsSection.about)
                    }
                    .padding(26)
                }
                .pocketPanel()
            }
        }
        .sheet(isPresented: $showingImport) { ImportDataView() }
        .sheet(isPresented: $showingExport) { ExportDataView() }
        .sheet(isPresented: $showingTags) { TagManagementView() }
        .sheet(isPresented: $showingAbout) { AboutPocketPassView() }
        .sheet(isPresented: $showingPrivacy) { PrivacyInfoView() }
    }

    private func settingsSidebar(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("设置")
                .font(.title2.bold())
                .padding(.horizontal, 8)
                .padding(.bottom, 10)

            ForEach(SettingsSection.allCases) { section in
                Button {
                    selection = section
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(section, anchor: .top)
                    }
                } label: {
                    Label(section.title, systemImage: section.icon)
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(selection == section ? PocketTheme.accent.opacity(0.32) : .clear)
                        .foregroundStyle(selection == section ? .white : PocketTheme.muted)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 220)
        .pocketPanel()
    }

    private var securitySection: some View {
        SettingsSectionView(title: "安全") {
            SettingsCard {
                SettingsToggleRow(
                    icon: "lock.fill",
                    title: "启用应用锁",
                    subtitle: "锁定后需使用 Touch ID 或设备密码解锁。",
                    isOn: Binding(
                        get: { store.appLockEnabled },
                        set: { enabled in
                            store.appLockEnabled = enabled
                            if enabled {
                                store.showingLockScreen = true
                            }
                        }
                    )
                )
                SettingsDivider()
                SettingsPickerRow(
                    icon: "timer",
                    title: "自动锁定",
                    subtitle: "应用离开前台后开始计时。",
                    selection: Bindable(store).lockAfterMinutes,
                    options: [(0, "立即"), (1, "1 分钟"), (5, "5 分钟"), (15, "15 分钟"), (30, "30 分钟")]
                )
                SettingsDivider()
                SettingsActionRow(icon: "lock.rotation", title: "预览锁定界面", subtitle: "立即检查当前解锁方式。") {
                    store.showingLockScreen = true
                }
            }
        }
    }

    private var cloudSection: some View {
        SettingsSectionView(title: "iCloud 同步") {
            SettingsCard {
                SettingsStatusRow(
                    icon: "icloud.fill",
                    title: "iCloud 同步",
                    subtitle: "首版暂不接入，当前数据仅保存在本机加密密码库中。",
                    status: "暂未开放"
                )
            }
        }
    }

    private var generalSection: some View {
        SettingsSectionView(title: "通用") {
            SettingsCard {
                SettingsPickerRow(
                    icon: "circle.lefthalf.filled",
                    title: "主题",
                    subtitle: "深色或跟随 macOS 外观。",
                    selection: Bindable(store).appearanceMode,
                    options: AppearanceMode.allCases.map { ($0, $0.rawValue) }
                )
                SettingsDivider()
                SettingsPickerRow(
                    icon: "arrow.up.arrow.down",
                    title: "首页排序",
                    subtitle: "决定首页账户列表的显示顺序。",
                    selection: Bindable(store).homeSortMode,
                    options: HomeSortMode.allCases.map { ($0, $0.rawValue) }
                )
            }
        }
    }

    private var contentSection: some View {
        SettingsSectionView(title: "内容") {
            SettingsCard {
                SettingsActionRow(icon: "tag.fill", title: "标签管理", subtitle: "新建、重命名或删除所有账户共用的标签。") {
                    showingTags = true
                }
                SettingsDivider()
                SettingsActionRow(icon: "folder.fill", title: "分类管理", subtitle: "新增、编辑分类的图标、名称和卡片颜色。") {
                    store.selectedSection = .categories
                    store.selectedCategoryID = nil
                }
                SettingsDivider()
                SettingsStatusRow(
                    icon: "photo.on.rectangle.angled",
                    title: "账户图标来源",
                    subtitle: "支持内置图标、9 个常见 App Store 区域、网站图标和相册图片。",
                    status: "已启用"
                )
            }
        }
    }

    private var dataSection: some View {
        SettingsSectionView(title: "数据") {
            SettingsCard {
                SettingsActionRow(icon: "square.and.arrow.down.fill", title: "导入数据", subtitle: "支持加密备份、JSON、CSV 和 Markdown 文件。") {
                    showingImport = true
                }
                SettingsDivider()
                SettingsActionRow(icon: "square.and.arrow.up.fill", title: "导出与本地加密备份", subtitle: "加密备份使用独立密码保护，也可导出 JSON、CSV 或 Markdown。") {
                    showingExport = true
                }
                SettingsDivider()
                SettingsStatusRow(
                    icon: "lock.shield.fill",
                    title: "本地存储保护",
                    subtitle: "密码库使用 AES-GCM 加密；应用不会读取系统钥匙串信息。",
                    status: "已加密"
                )
            }
        }
    }

    private var aboutSection: some View {
        SettingsSectionView(title: "关于") {
            SettingsCard {
                SettingsActionRow(icon: "info.circle.fill", title: "关于口袋密码", subtitle: "本地优先的原生 Mac 账户密码管理器。") {
                    showingAbout = true
                }
                SettingsDivider()
                SettingsActionRow(icon: "hand.raised.fill", title: "隐私说明", subtitle: "查看本地存储和网络访问说明。") {
                    showingPrivacy = true
                }
                SettingsDivider()
                SettingsStatusRow(icon: "shippingbox.fill", title: "版本", subtitle: "macOS 26 原生 Demo", status: appVersion)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "V\(version)(\(build))"
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case security, cloud, general, content, data, about
    var id: Self { self }
    var title: String {
        switch self {
        case .security: "安全"
        case .cloud: "iCloud 同步"
        case .general: "通用"
        case .content: "内容"
        case .data: "数据"
        case .about: "关于"
        }
    }
    var icon: String {
        switch self {
        case .security: "lock.fill"
        case .cloud: "icloud.fill"
        case .general: "slider.horizontal.3"
        case .content: "square.grid.2x2.fill"
        case .data: "externaldrive.fill"
        case .about: "info.circle.fill"
        }
    }
}

private struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline.bold())
            content
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(PocketTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.035)))
    }
}

private struct SettingsDivider: View {
    var body: some View { Divider().overlay(.white.opacity(0.07)).padding(.leading, 46) }
}

private struct SettingsRowLabel: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PocketTheme.muted)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.semibold)).foregroundStyle(.white)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(PocketTheme.muted).lineLimit(2)
                }
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 16) {
            SettingsRowLabel(icon: icon, title: title, subtitle: subtitle)
            Spacer(minLength: 20)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(PocketTheme.accent)
        }
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                SettingsRowLabel(icon: icon, title: title, subtitle: subtitle)
                Spacer(minLength: 20)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(PocketTheme.muted)
            }
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsStatusRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: String
    var body: some View {
        HStack(spacing: 16) {
            SettingsRowLabel(icon: icon, title: title, subtitle: subtitle)
            Spacer(minLength: 20)
            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PocketTheme.accent)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(PocketTheme.accent.opacity(0.12))
                .clipShape(Capsule())
        }
        .frame(minHeight: 64)
    }
}

private struct SettingsPickerRow<Value: Hashable>: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var selection: Value
    let options: [(Value, String)]
    var body: some View {
        HStack(spacing: 16) {
            SettingsRowLabel(icon: icon, title: title, subtitle: subtitle)
            Spacer(minLength: 20)
            Picker("", selection: $selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Text(option.1).tag(option.0)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(minWidth: 120)
        }
        .frame(minHeight: 64)
    }
}

private struct AboutPocketPassView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                InterfaceBrandLogoView(size: 34)
                Text("关于口袋密码").font(.title2.bold())
                Spacer()
                Button("完成") { dismiss() }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
            }
            InterfaceBrandLogoView(size: 84)
            Text("口袋密码").font(.title.bold())
            Text("PocketPass").font(.headline).foregroundStyle(.secondary)
            Text("本地优先的原生 Mac 账户密码管理器")
                .foregroundStyle(PocketTheme.muted)
            Text("支持多登录账号、自定义字段、分类、标签、图片附件、回收站以及本地加密导入导出。")
                .multilineTextAlignment(.center)
                .foregroundStyle(PocketTheme.muted)
                .frame(maxWidth: 430)
            Spacer()
        }
        .padding(28)
        .frame(width: 560, height: 380)
        .background(PocketTheme.background)
        .buttonBorderShape(.capsule)
    }
}

private struct PrivacyInfoView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                InterfaceBrandLogoView(size: 30)
                Text("隐私说明").font(.title2.bold())
                Spacer()
                Button("完成") { dismiss() }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
            }
            PrivacyLine(icon: "lock.shield.fill", title: "本地加密", detail: "账户、密码、分类、标签和图片附件写入本机 AES-GCM 加密密码库。")
            PrivacyLine(icon: "key.slash.fill", title: "不读取钥匙串", detail: "口袋密码不会读取 macOS 钥匙串中的密码或机密信息。")
            PrivacyLine(icon: "network", title: "按需联网", detail: "只有在你主动搜索 App Store 图标或通过网址获取网站图标时发起网络请求。")
            PrivacyLine(icon: "icloud.slash.fill", title: "尚未接入 iCloud", detail: "当前 Demo 不上传密码库，iCloud 同步将在后续版本独立开发。")
            Spacer()
        }
        .padding(28)
        .frame(width: 640, height: 430)
        .background(PocketTheme.background)
        .buttonBorderShape(.capsule)
    }
}

private struct PrivacyLine: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).foregroundStyle(PocketTheme.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(PocketTheme.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PocketTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
