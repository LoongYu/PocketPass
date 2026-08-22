import PhotosUI
import SwiftUI

struct IOSIconPickerView: View {
    @EnvironmentObject private var store: VaultStore
    @EnvironmentObject private var settings: IOSAppSettings
    @Environment(\.dismiss) private var dismiss
    @Binding var symbol: String
    @Binding var iconData: Data?
    @State private var tab = 0
    @State private var searchText = ""
    @State private var region: AppStoreRegion = .china
    @State private var appResults: [AppStoreSearchResult] = []
    @State private var website = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let symbols = [
        "person.crop.circle.fill", "person.fill", "person.2.fill", "person.3.fill", "person.badge.key.fill",
        "key.fill", "key.horizontal.fill", "lock.fill", "lock.open.fill", "lock.shield.fill", "shield.fill",
        "checkmark.seal.fill", "faceid", "touchid", "bolt.fill", "folder.fill", "doc.fill", "note.text",
        "list.bullet", "archivebox.fill", "bookmark.fill", "square.and.pencil", "pencil", "message.fill",
        "bubble.left.and.bubble.right.fill", "phone.fill", "envelope.fill", "paperplane.fill", "video.fill",
        "mic.fill", "at", "link", "globe", "creditcard.fill", "banknote.fill", "chart.line.uptrend.xyaxis",
        "gift.fill", "ticket.fill", "briefcase.fill", "building.2.fill", "building.columns.fill", "calendar",
        "clock.fill", "cart.fill", "bag.fill", "storefront.fill", "house.fill", "heart.fill", "leaf.fill",
        "airplane", "car.fill", "bus.fill", "tram.fill", "suitcase.fill", "map.fill", "location.fill",
        "gamecontroller.fill", "music.note", "headphones", "tv.fill", "film.fill", "camera.fill", "photo.fill"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("图标来源", selection: $tab) {
                    Text("图标库").tag(0)
                    Text("App Store").tag(1)
                    Text("网址").tag(2)
                    Text("相册").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch tab {
                    case 0: libraryTab
                    case 1: appStoreTab
                    case 2: websiteTab
                    default: photoTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 8)
            .background(IOSTheme.background)
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .overlay {
                if isLoading { ProgressView().controlSize(.large).padding(28).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20)) }
            }
            .alert("获取图标失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var libraryTab: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(symbols, id: \.self) { name in
                    Button { choose(symbol: name, data: nil) } label: {
                        Image(systemName: name)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(symbol == name && iconData == nil ? .black : .primary)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(symbol == name && iconData == nil ? IOSTheme.accent : IOSTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                ForEach(store.customIcons) { icon in
                    Button { choose(symbol: "photo", data: icon.data) } label: {
                        IOSVaultIcon(symbol: "photo", data: icon.data, size: 58, background: IOSTheme.panel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private var appStoreTab: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(AppStoreRegion.allCases) { option in
                        Button {
                            region = option
                            if !searchText.isEmpty { Task { await searchAppStore() } }
                        } label: {
                            if option == region { Label("\(option.flag) \(option.name)", systemImage: "checkmark") }
                            else { Text("\(option.flag) \(option.name)") }
                        }
                    }
                } label: {
                    Text(region.flag).font(.title2).frame(width: 48, height: 46).background(IOSTheme.panel, in: Capsule())
                }
                TextField("搜索 App Store", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(IOSTheme.panel, in: Capsule())
                    .onSubmit { Task { await searchAppStore() } }
                Button { Task { await searchAppStore() } } label: {
                    Image(systemName: "magnifyingglass").frame(width: 46, height: 46).background(IOSTheme.accent, in: Circle()).foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            if appResults.isEmpty, !isLoading {
                ContentUnavailableView("App Store 图标", systemImage: "apple.logo", description: Text("默认搜索中国区，可通过国旗切换 9 个常用区域"))
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                        ForEach(appResults) { result in
                            Button { Task { await chooseRemote(result.artworkUrl100) } } label: {
                                VStack(spacing: 7) {
                                    AsyncImage(url: result.artworkUrl100) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                                        .frame(width: 62, height: 62)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text(result.trackName).font(.caption2).lineLimit(2).foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var websiteTab: some View {
        VStack(spacing: 18) {
            Image(systemName: "globe").font(.system(size: 48)).foregroundStyle(IOSTheme.accent)
            TextField("输入网址，例如 github.com", text: $website)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .padding(16)
                .background(IOSTheme.panel, in: RoundedRectangle(cornerRadius: 18))
            Button {
                Task { await fetchFavicon() }
            } label: {
                Label("获取网站图标", systemImage: "arrow.down.circle.fill")
                    .fontWeight(.bold).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14).background(IOSTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer()
        }
        .padding(22)
    }

    private var photoTab: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 48)).foregroundStyle(IOSTheme.accent)
            Text("从相册选择一张图片作为账户或分类图标")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("选择图片", systemImage: "photo.badge.plus")
                    .fontWeight(.bold).foregroundStyle(.black).padding(.horizontal, 22).padding(.vertical, 14).background(IOSTheme.accent, in: Capsule())
            }
            Spacer()
        }
        .padding(22)
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self), data.count <= 20_000_000 else {
                    errorMessage = imageProcessingError
                    return
                }
                choose(symbol: "photo", data: data)
            }
        }
    }

    @MainActor
    private func searchAppStore() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do { appResults = try await RemoteIconService.searchAppStore(searchText, region: region) }
        catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func chooseRemote(_ url: URL) async {
        isLoading = true
        defer { isLoading = false }
        do { choose(symbol: "photo", data: try await RemoteIconService.downloadImage(url)) }
        catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func fetchFavicon() async {
        isLoading = true
        defer { isLoading = false }
        do { choose(symbol: "globe", data: try await RemoteIconService.favicon(for: website)) }
        catch { errorMessage = error.localizedDescription }
    }

    private func choose(symbol: String, data: Data?) {
        self.symbol = symbol
        if let data {
            guard let normalized = IOSImageProcessor.normalizedIconData(data) else {
                errorMessage = imageProcessingError
                return
            }
            iconData = normalized
        } else {
            iconData = nil
        }
        dismiss()
    }

    private var imageProcessingError: String {
        settings.language.text(
            "图片无法读取或处理后仍然过大",
            "The image could not be read or is still too large after processing."
        )
    }
}
