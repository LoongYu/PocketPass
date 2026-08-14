import CryptoKit
import CommonCrypto
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct TransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, DataTransferService.markdownType, UTType(exportedAs: "com.loongyu.pockit.backup")] }
    var data = Data()

    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum DataTransferService {
    static let backupType = UTType(exportedAs: "com.loongyu.pockit.backup", conformingTo: .data)
    static let markdownType = UTType(filenameExtension: "md") ?? .plainText
    private static let magic = Data("POCKETPASS1".utf8)

    static func json(snapshot: VaultSnapshot) throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    static func snapshot(fromJSON data: Data) throws -> VaultSnapshot {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VaultSnapshot.self, from: data)
    }

    static func csv(snapshot: VaultSnapshot) -> Data {
        var rows = ["名称,网址,分类,标签,用户名,密码,备注"]
        let categoryNames = Dictionary(uniqueKeysWithValues: snapshot.categories.map { ($0.id, $0.name) })
        for item in snapshot.items where item.deletedAt == nil {
            for account in item.accounts {
                rows.append([item.name, item.website, categoryNames[item.categoryID] ?? "其他",
                             item.tags.joined(separator: "|"), account.username, account.password, item.note]
                    .map(csvEscape).joined(separator: ","))
            }
        }
        return Data(rows.joined(separator: "\n").utf8)
    }

    static func markdown(snapshot: VaultSnapshot) -> Data {
        let categoryNames = Dictionary(uniqueKeysWithValues: snapshot.categories.map { ($0.id, $0.name) })
        var lines = [
            "# 口袋密码导出",
            "",
            "> 此文件包含明文账户和密码，请妥善保管。",
            ""
        ]
        for item in snapshot.items where item.deletedAt == nil {
            lines.append("### \(markdownEscape(item.name))")
            lines.append("分类：\(markdownEscape(categoryNames[item.categoryID] ?? "其他"))")
            if !item.tags.isEmpty { lines.append("标签：\(markdownEscape(item.tags.joined(separator: "、")))") }
            if !item.website.isEmpty { lines.append("网址：\(markdownEscape(item.website))") }
            if !item.note.isEmpty { lines.append("备注：\(markdownEscape(item.note))") }
            for account in item.accounts {
                lines.append("用户名：\(markdownEscape(account.username))")
                lines.append("密码：\(markdownEscape(account.password))")
                for field in account.fields {
                    lines.append("\(markdownEscape(field.name))：\(markdownEscape(field.value))")
                }
                lines.append("")
            }
            if item.accounts.isEmpty { lines.append("") }
        }
        return Data(lines.joined(separator: "  \n").utf8)
    }

    static func snapshot(fromMarkdown data: Data, baseCategories: [VaultCategory]) throws -> VaultSnapshot {
        guard var text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        text = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
            .unicodeScalars.filter { $0.value == 9 || $0.value == 10 || $0.value >= 32 }
            .map(String.init).joined()

        let rawLines = text.components(separatedBy: "\n")
        var sections: [MarkdownSection] = []
        var currentTitle = ""
        var currentBlock: [(String, String)] = []
        var currentBlocks: [[(String, String)]] = []

        func finishBlock() {
            guard !currentBlock.isEmpty else { return }
            currentBlocks.append(currentBlock)
            currentBlock = []
        }
        func finishSection() {
            finishBlock()
            let title = cleanMarkdownTitle(currentTitle)
            if !title.isEmpty, !currentBlocks.isEmpty {
                sections.append(.init(title: title, blocks: currentBlocks))
            }
            currentTitle = ""
            currentBlocks = []
        }

        for index in rawLines.indices {
            let line = cleanMarkdownLine(rawLines[index])
            if line.isEmpty {
                finishBlock()
                continue
            }
            if isMarkdownSeparator(line) || line.hasPrefix(">") { continue }

            if let heading = markdownHeading(line) {
                guard !heading.isEmpty else { continue }
                finishSection()
                currentTitle = heading
                continue
            }

            if parseMarkdownPair(line) == nil, nextMeaningfulLineIsPair(after: index, lines: rawLines) {
                finishSection()
                currentTitle = line
                continue
            }

            if let pair = parseMarkdownPair(line), !currentTitle.isEmpty {
                currentBlock.append(pair)
            }
        }
        finishSection()

        var categories = baseCategories
        var items: [VaultItem] = []
        var itemIndexByName: [String: Int] = [:]

        func categoryID(named name: String) -> UUID {
            let cleaned = cleanMarkdownTitle(name).isEmpty ? "其他" : cleanMarkdownTitle(name)
            if let existing = categories.first(where: { $0.name.caseInsensitiveCompare(cleaned) == .orderedSame }) {
                return existing.id
            }
            let category = VaultCategory(id: UUID(), name: cleaned, icon: "folder.fill", colorHex: "888888")
            categories.append(category)
            return category.id
        }

        let fallbackCategoryID = categoryID(named: "其他")
        for section in sections {
            let mergeKey = section.title.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
            for block in section.blocks {
                let metadata = Dictionary(block, uniquingKeysWith: { _, newest in newest })
                let categoryName = metadataValue(metadata, keys: ["分类"])
                let tags = metadataValue(metadata, keys: ["标签"])
                    .split(whereSeparator: { "、,，|".contains($0) }).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let website = metadataValue(metadata, keys: ["网址", "官网", "地址"])
                let note = metadataValue(metadata, keys: ["备注"])

                let usernameKeys = ["用户名", "用户名称", "账号", "账户", "微信 ID", "微信ID", "ID", "邮箱", "邮件", "手机号", "手机", "号码"]
                let usernameEntry = firstMarkdownEntry(in: block, keys: usernameKeys)
                let passwordEntry = block.first { normalizeMarkdownKey($0.0).contains("密码") }
                let ignoredKeys = Set(["分类", "标签", "网址", "官网", "地址", "备注"])
                let customFields = block.compactMap { entry -> CustomField? in
                    let normalized = normalizeMarkdownKey(entry.0)
                    if ignoredKeys.contains(normalized) || entry.0 == usernameEntry?.0 || entry.0 == passwordEntry?.0 { return nil }
                    return CustomField(id: UUID(), name: entry.0, value: entry.1,
                                       isSecret: normalized.contains("PIN") || normalized.contains("密保答案"))
                }
                let account = LoginAccount(id: UUID(), username: usernameEntry?.1 ?? "", password: passwordEntry?.1 ?? "", fields: customFields)

                if let existingIndex = itemIndexByName[mergeKey] {
                    items[existingIndex].accounts.append(account)
                    items[existingIndex].tags = Array(Set(items[existingIndex].tags + tags)).sorted()
                    if items[existingIndex].website.isEmpty { items[existingIndex].website = website }
                    if !note.isEmpty, !items[existingIndex].note.contains(note) {
                        items[existingIndex].note += items[existingIndex].note.isEmpty ? note : "\n\(note)"
                    }
                    if !categoryName.isEmpty { items[existingIndex].categoryID = categoryID(named: categoryName) }
                } else {
                    let item = VaultItem(
                        id: UUID(), name: section.title, website: website,
                        categoryID: categoryName.isEmpty ? fallbackCategoryID : categoryID(named: categoryName),
                        tags: tags, note: note, symbol: "key.fill", accounts: [account],
                        isFavorite: false, modifiedAt: .now, deletedAt: nil
                    )
                    itemIndexByName[mergeKey] = items.count
                    items.append(item)
                }
            }
        }
        return .init(categories: categories, items: items)
    }

    static func encryptedBackup(snapshot: VaultSnapshot, password: String) throws -> Data {
        let plaintext = try json(snapshot: snapshot)
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let key = try backupKey(password: password, salt: salt)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw VaultStorageError.malformedCiphertext }
        var output = magic; output.append(salt); output.append(combined)
        return output
    }

    static func decryptBackup(_ data: Data, password: String) throws -> VaultSnapshot {
        guard data.starts(with: magic), data.count > magic.count + 16 else { throw VaultStorageError.malformedCiphertext }
        let saltStart = magic.count, cipherStart = saltStart + 16
        let salt = data[saltStart..<cipherStart]
        let box = try AES.GCM.SealedBox(combined: data[cipherStart...])
        let plaintext = try AES.GCM.open(box, using: backupKey(password: password, salt: Data(salt)))
        return try snapshot(fromJSON: plaintext)
    }

    static func isEncryptedBackup(_ data: Data) -> Bool { data.starts(with: magic) }

    static func snapshot(fromCSV data: Data, baseCategories: [VaultCategory]) throws -> VaultSnapshot {
        guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        let rows = parseCSV(text)
        guard rows.count > 1 else { return .init(categories: baseCategories, items: []) }
        var categories = baseCategories
        var items: [VaultItem] = []
        for columns in rows.dropFirst() where columns.count >= 7 {
            let categoryName = columns[2].isEmpty ? "其他" : columns[2]
            let categoryID: UUID
            if let existing = categories.first(where: { $0.name == categoryName }) { categoryID = existing.id }
            else {
                let category = VaultCategory(id: UUID(), name: categoryName, icon: "folder.fill", colorHex: "888888")
                categories.append(category); categoryID = category.id
            }
            items.append(.init(id: UUID(), name: columns[0], website: columns[1], categoryID: categoryID,
                               tags: columns[3].split(separator: "|").map(String.init), note: columns[6], symbol: "key.fill",
                               accounts: [.init(id: UUID(), username: columns[4], password: columns[5], fields: [])],
                               isFavorite: false, modifiedAt: .now, deletedAt: nil))
        }
        return .init(categories: categories, items: items)
    }

    private static func backupKey(password: String, salt: Data) throws -> SymmetricKey {
        var derived = [UInt8](repeating: 0, count: 32)
        let status = password.withCString { passwordPointer in
            salt.withUnsafeBytes { saltPointer in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), passwordPointer, password.utf8.count,
                                     saltPointer.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 200_000,
                                     &derived, derived.count)
            }
        }
        guard status == kCCSuccess else { throw VaultStorageError.malformedCiphertext }
        return SymmetricKey(data: Data(derived))
    }

    private static func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private struct MarkdownSection {
        var title: String
        var blocks: [[(String, String)]]
    }

    private static func cleanMarkdownLine(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }

    private static func cleanMarkdownTitle(_ value: String) -> String {
        var cleaned = cleanMarkdownLine(value)
        while cleaned.last == "：" || cleaned.last == ":" { cleaned.removeLast() }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func markdownHeading(_ line: String) -> String? {
        guard line.hasPrefix("#") else { return nil }
        return cleanMarkdownTitle(String(line.drop(while: { $0 == "#" || $0.isWhitespace })))
    }

    private static func isMarkdownSeparator(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        return !compact.isEmpty && compact.allSatisfy { "=-_*".contains($0) }
    }

    private static func parseMarkdownPair(_ line: String) -> (String, String)? {
        var cleaned = line
        while cleaned.first == "-" || cleaned.first == "*" { cleaned.removeFirst(); cleaned = cleanMarkdownLine(cleaned) }
        guard let separator = cleaned.firstIndex(where: { $0 == "：" || $0 == ":" }) else { return nil }
        let key = cleanMarkdownLine(String(cleaned[..<separator]))
        guard !key.isEmpty else { return nil }
        let value = cleanMarkdownLine(String(cleaned[cleaned.index(after: separator)...]))
        return (key, value)
    }

    private static func nextMeaningfulLineIsPair(after index: Int, lines: [String]) -> Bool {
        guard index + 1 < lines.count else { return false }
        for candidateIndex in (index + 1)..<lines.count {
            let candidate = cleanMarkdownLine(lines[candidateIndex])
            if candidate.isEmpty || isMarkdownSeparator(candidate) { continue }
            return parseMarkdownPair(candidate) != nil
        }
        return false
    }

    private static func normalizeMarkdownKey(_ key: String) -> String {
        cleanMarkdownTitle(key).replacingOccurrences(of: " ", with: "").uppercased()
    }

    private static func metadataValue(_ metadata: [String: String], keys: [String]) -> String {
        for key in keys {
            if let match = metadata.first(where: { normalizeMarkdownKey($0.key) == normalizeMarkdownKey(key) }) {
                return match.value
            }
        }
        return ""
    }

    private static func firstMarkdownEntry(in block: [(String, String)], keys: [String]) -> (String, String)? {
        for key in keys {
            if let entry = block.first(where: { normalizeMarkdownKey($0.0) == normalizeMarkdownKey(key) && !$0.1.isEmpty }) {
                return entry
            }
        }
        return nil
    }

    private static func markdownEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " / ")
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\"" {
                let next = text.index(after: index)
                if quoted, next < text.endIndex, text[next] == "\"" { field.append("\""); index = next }
                else { quoted.toggle() }
            } else if character == ",", !quoted { row.append(field); field = "" }
            else if character == "\n", !quoted { row.append(field); rows.append(row); row = []; field = "" }
            else if character != "\r" { field.append(character) }
            index = text.index(after: index)
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}
