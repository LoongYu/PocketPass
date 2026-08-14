import SwiftUI
import UniformTypeIdentifiers

struct IconPickerView: View {
    enum Source: String, CaseIterable, Identifiable {
        case library = "图标库"
        case appStore = "App Store"
        case website = "网址"
        case photos = "相册"
        var id: Self { self }
    }

    @Binding var selectedIcon: String
    @Binding var selectedIconData: Data?
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var source: Source = .library
    @State private var searchText = ""
    @State private var appStoreRegion: AppStoreRegion = .china
    @State private var website = "https://"
    @State private var showingPhotoPicker = false
    @State private var appStoreResults: [AppStoreSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @Namespace private var sourceAnimation

    private let icons = [
        "person.crop.circle", "person.crop.circle.fill", "person.fill", "person.2.fill", "person.3.fill",
        "person.badge.key.fill", "person.crop.circle.badge.plus", "key.fill", "key.horizontal.fill",
        "lock.fill", "lock.open.fill", "lock.shield.fill", "lock.rotation", "shield.fill",
        "shield.checkered", "shield.lefthalf.filled", "checkmark.seal.fill", "faceid", "touchid",
        "bolt.fill", "bolt.shield.fill", "exclamationmark.shield.fill", "folder.fill", "folder.badge.plus",
        "doc.fill", "doc.text.fill", "doc.on.doc.fill", "note.text", "list.bullet", "list.clipboard.fill",
        "tray.full.fill", "archivebox.fill", "bookmark.fill", "square.and.pencil", "pencil", "signature",
        "message.fill", "bubble.left.and.bubble.right.fill", "phone.fill", "phone.bubble.left.fill",
        "envelope.fill", "paperplane.fill", "video.fill", "mic.fill", "at", "link", "globe",
        "creditcard.fill", "banknote.fill", "dollarsign.circle.fill", "yensign.circle.fill",
        "chart.line.uptrend.xyaxis", "chart.pie.fill", "gift.fill", "ticket.fill", "percent",
        "briefcase.fill", "building.2.fill", "building.columns.fill", "printer.fill", "calendar",
        "calendar.badge.clock", "clock.fill", "timer", "stopwatch.fill", "hourglass",
        "cart.fill", "bag.fill", "basket.fill", "storefront.fill", "house.fill", "heart.fill",
        "leaf.fill", "airplane", "car.fill", "bus.fill", "tram.fill", "bicycle", "fuelpump.fill",
        "suitcase.fill", "map.fill", "location.fill", "mappin.and.ellipse", "gamecontroller.fill",
        "sportscourt.fill", "music.note", "headphones", "tv.fill", "film.fill", "camera.fill",
        "photo.fill", "desktopcomputer", "laptopcomputer", "iphone", "applewatch", "cloud.fill",
        "server.rack", "externaldrive.fill", "terminal.fill", "chevron.left.forwardslash.chevron.right"
    ]

    private var visibleIcons: [String] {
        searchText.isEmpty ? icons : icons.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var visibleCustomIcons: [CustomIcon] {
        searchText.isEmpty ? store.customIcons : store.customIcons.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                InterfaceBrandLogoView(size: 21)
                Text("选择图标").font(.title3.bold())
                Spacer(); Button("取消") { dismiss() }.buttonStyle(.bordered)
            }.padding(.horizontal, 22).padding(.vertical, 18)

            sourcePicker.padding(.horizontal, 22).padding(.bottom, 16)

            Group {
                switch source {
                case .library: libraryView
                case .appStore: appStoreView
                case .website: websiteView
                case .photos: photosView
                }
            }
            .id(source)
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 650, height: 520).background(PocketTheme.background)
        .buttonBorderShape(.capsule)
        .fileImporter(isPresented: $showingPhotoPicker, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), data.count <= 5_000_000 else {
                errorMessage = store.appLanguage.text("图片无法读取或超过5 MB", "The image cannot be read or exceeds 5 MB"); return
            }
            selectedIcon = "photo.fill"; selectedIconData = data; dismiss()
        }
    }

    private var libraryView: some View {
        VStack(spacing: 14) {
            iconSearch
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !visibleCustomIcons.isEmpty {
                        Text("自定义图标").font(.caption.bold()).foregroundStyle(PocketTheme.muted)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 11) {
                            ForEach(visibleCustomIcons) { icon in
                                Button { choose(icon) } label: {
                                    if let image = NSImage(data: icon.data) {
                                        Image(nsImage: image).resizable().scaledToFit()
                                            .frame(width: 30, height: 30)
                                            .frame(maxWidth: .infinity).frame(height: 44)
                                            .background(selectedIconData == icon.data ? PocketTheme.accent.opacity(0.2) : PocketTheme.card)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(selectedIconData == icon.data ? PocketTheme.accent : PocketTheme.border))
                                    }
                                }.buttonStyle(.plain).help(icon.name)
                            }
                        }
                    }

                    Text("系统图标").font(.caption.bold()).foregroundStyle(PocketTheme.muted)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 11) {
                        ForEach(visibleIcons, id: \.self) { icon in
                            Button { choose(icon) } label: {
                                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(selectedIcon == icon && selectedIconData == nil ? PocketTheme.accent.opacity(0.2) : PocketTheme.card)
                                    .foregroundStyle(selectedIcon == icon && selectedIconData == nil ? PocketTheme.accent : PocketTheme.primary.opacity(0.82))
                                    .clipShape(Capsule())
                                    .overlay(Capsule()
                                        .stroke(selectedIcon == icon && selectedIconData == nil ? PocketTheme.accent : PocketTheme.border))
                            }.buttonStyle(.plain).help(icon)
                        }
                    }
                }.padding(.vertical, 4)
            }
        }.padding(.horizontal, 22).padding(.bottom, 18)
    }

    private var sourcePicker: some View {
        HStack(spacing: 4) {
            ForEach(Source.allCases) { item in
                Button {
                    withAnimation(.smooth(duration: 0.28)) {
                        source = item
                        searchText = ""
                    }
                } label: {
                    Text(LocalizedStringKey(item.rawValue)).font(.caption.bold()).frame(maxWidth: .infinity)
                        .padding(.vertical, 9).contentShape(Rectangle())
                        .background {
                            if source == item {
                                Capsule().fill(PocketTheme.elevated)
                                    .matchedGeometryEffect(id: "sourceSelection", in: sourceAnimation)
                            }
                        }
                }.buttonStyle(.plain).foregroundStyle(source == item ? PocketTheme.primary : PocketTheme.muted)
            }
        }.padding(4).background(PocketTheme.card).clipShape(Capsule())
    }

    private var appStoreView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                appStoreRegionPicker
                iconSearch
                Button("搜索") { searchAppStore() }.buttonStyle(.borderedProminent)
                    .tint(PocketTheme.accent).foregroundStyle(.black).disabled(searchText.isEmpty || isLoading)
            }
            Text("搜索所选地区的 App Store 应用并使用其图标")
                .font(.caption).foregroundStyle(PocketTheme.muted)
            if isLoading { ProgressView().frame(maxWidth: .infinity) }
            if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundStyle(.red) }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                    ForEach(appStoreResults) { result in
                        Button { selectAppStore(result) } label: {
                            VStack(spacing: 7) {
                                AsyncImage(url: result.artworkUrl100) { image in image.resizable().scaledToFill() }
                                    placeholder: { RoundedRectangle(cornerRadius: 13).fill(PocketTheme.card).overlay { ProgressView() } }
                                    .frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 13))
                                Text(result.trackName).font(.caption2).lineLimit(1)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
            Spacer()
        }.padding(.horizontal, 22).padding(.bottom, 20)
    }

    private var appStoreRegionPicker: some View {
        Menu {
            ForEach(AppStoreRegion.allCases) { region in
                Button {
                    appStoreRegion = region
                    appStoreResults = []
                    errorMessage = ""
                } label: {
                    HStack {
                        if appStoreRegion == region { Image(systemName: "checkmark") }
                        Text(region.flag)
                        Text(LocalizedStringKey(region.name))
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(appStoreRegion.flag)
                    .font(.system(size: 19))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PocketTheme.muted)
            }
            .padding(.horizontal, 11)
            .frame(height: 38)
            .background(PocketTheme.card)
            .clipShape(Capsule())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help("App Store 地区：\(appStoreRegion.name)")
    }

    private var websiteView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("输入网站地址").font(.headline)
            Text("将优先查找 Apple Touch Icon，其次查找 favicon。")
                .font(.caption).foregroundStyle(PocketTheme.muted)
            HStack {
                Image(systemName: "globe").foregroundStyle(PocketTheme.muted)
                TextField("https://example.com", text: $website).textFieldStyle(.plain)
                Button("获取图标") { loadWebsiteIcon() }.buttonStyle(.borderedProminent)
                    .tint(PocketTheme.accent).foregroundStyle(.black)
            }.padding(13).background(PocketTheme.card).clipShape(RoundedRectangle(cornerRadius: 13))
            if isLoading { ProgressView("正在获取网站图标…") }
            if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundStyle(.red) }
            Spacer()
        }.padding(22)
    }

    private var photosView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 54)).foregroundStyle(PocketTheme.accent)
            Text("从相册或本地文件选择图片").font(.headline)
            Text("支持 PNG、JPEG、HEIC 等常见图片格式").font(.caption).foregroundStyle(PocketTheme.muted)
            Button("选择图片") { showingPhotoPicker = true }.buttonStyle(.borderedProminent)
                .tint(PocketTheme.accent).foregroundStyle(.black)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconSearch: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(PocketTheme.muted)
            TextField(source == .appStore ? "搜索 App Store" : "搜索图标", text: $searchText).textFieldStyle(.plain)
        }.padding(11).background(PocketTheme.card).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func choose(_ symbol: String) {
        selectedIcon = symbol
        selectedIconData = nil
        dismiss()
    }

    private func choose(_ icon: CustomIcon) {
        selectedIcon = "photo.fill"
        selectedIconData = icon.data
        dismiss()
    }

    private func searchAppStore() {
        errorMessage = ""; isLoading = true
        Task {
            do { appStoreResults = try await RemoteIconService.searchAppStore(searchText, region: appStoreRegion) }
            catch { errorMessage = store.appLanguage.text("App Store 搜索失败，请稍后重试", "App Store search failed. Try again later.") }
            isLoading = false
        }
    }

    private func selectAppStore(_ result: AppStoreSearchResult) {
        errorMessage = ""; isLoading = true
        Task {
            do {
                selectedIconData = try await RemoteIconService.downloadImage(result.artworkUrl100)
                selectedIcon = "app.fill"
                dismiss()
            } catch { errorMessage = store.appLanguage.text("图标下载失败", "Icon download failed"); isLoading = false }
        }
    }

    private func loadWebsiteIcon() {
        errorMessage = ""; isLoading = true
        Task {
            do {
                selectedIconData = try await RemoteIconService.favicon(for: website)
                selectedIcon = "globe"
                dismiss()
            } catch { errorMessage = store.appLanguage.text("未能获取该网站的图标", "Could not fetch an icon from this website"); isLoading = false }
        }
    }
}
