import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct CustomIconLibraryView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showingImporter = false
    @State private var message = ""
    @State private var iconToDelete: CustomIcon?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                InterfaceBrandLogoView(size: 21)
                Text("图标库").font(.title3.bold())
                Spacer()
                Button("完成") { dismiss() }.buttonStyle(.borderedProminent)
                    .tint(PocketTheme.accent).foregroundStyle(PocketTheme.primaryButtonText)
            }
            .padding(.horizontal, 22).padding(.vertical, 18)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自定义图标").font(.headline)
                    Text("最多保存 100 个图标，图片会自动缩放以减少存储占用。")
                        .font(.caption).foregroundStyle(PocketTheme.muted)
                }
                Spacer()
                Text("\(store.customIcons.count)/100")
                    .font(.caption.monospacedDigit()).foregroundStyle(PocketTheme.muted)
                Button { showingImporter = true } label: {
                    Label("上传图片", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent).tint(PocketTheme.accent).foregroundStyle(PocketTheme.primaryButtonText)
                .disabled(store.customIcons.count >= 100)
            }
            .padding(.horizontal, 22).padding(.bottom, 14)

            if !message.isEmpty {
                Text(message).font(.caption).foregroundStyle(PocketTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22).padding(.bottom, 10)
            }

            if store.customIcons.isEmpty {
                ContentUnavailableView(
                    "图标库为空",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("上传 PNG、JPEG、HEIC 等图片，可在账户和分类中重复使用。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 14) {
                        ForEach(store.customIcons) { icon in
                            customIconCard(icon)
                        }
                    }
                    .padding(.horizontal, 22).padding(.bottom, 22)
                }
            }
        }
        .frame(width: 620, height: 500)
        .background(PocketTheme.background)
        .buttonBorderShape(.capsule)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            importImages(result)
        }
        .confirmationDialog("从图标库删除？", isPresented: Binding(
            get: { iconToDelete != nil },
            set: { if !$0 { iconToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("删除图标", role: .destructive) {
                if let iconToDelete { store.deleteCustomIcon(iconToDelete.id) }
                iconToDelete = nil
            }
            Button("取消", role: .cancel) { iconToDelete = nil }
        } message: {
            Text("已使用该图片的账户和分类不会受到影响。")
        }
    }

    private func customIconCard(_ icon: CustomIcon) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let image = NSImage(data: icon.data) {
                    Image(nsImage: image).resizable().scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                Button { iconToDelete = icon } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.red)
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -7)
            }
            Text(icon.name).font(.caption).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(PocketTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func importImages(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else {
            message = store.appLanguage.text("未能读取所选图片", "Could not read the selected images")
            return
        }
        var icons: [CustomIcon] = []
        var failed = 0
        for url in urls.prefix(max(0, 100 - store.customIcons.count)) {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let raw = try? Data(contentsOf: url), raw.count <= 20_000_000,
                  let normalized = Self.normalizedIconData(raw), normalized.count <= 2_000_000 else {
                failed += 1
                continue
            }
            icons.append(.init(
                id: UUID(),
                name: url.deletingPathExtension().lastPathComponent,
                data: normalized,
                addedAt: .now
            ))
        }
        let added = store.addCustomIcons(icons)
        if failed > 0 {
            message = store.appLanguage.text("已添加 \(added) 个，\(failed) 个图片无法处理", "Added \(added); \(failed) images could not be processed")
        } else {
            message = store.appLanguage.text("已添加 \(added) 个图标", "Added \(added) icons")
        }
    }

    static func normalizedIconData(_ data: Data) -> Data? {
        guard safePixelDimensions(data) else { return nil }
        guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let maximum: CGFloat = 512
        let scale = min(1, maximum / max(image.size.width, image.size.height))
        let size = NSSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let output = NSImage(size: size)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        output.unlockFocus()
        guard let tiff = output.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func safePixelDimensions(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return false }
        return width > 0 && height > 0 && width <= 8_192 && height <= 8_192 && width * height <= 40_000_000
    }
}
