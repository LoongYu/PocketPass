import Foundation

enum PasswordGeneratorService {
    private static let lowercase = Array("abcdefghijkmnopqrstuvwxyz")
    private static let uppercase = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
    private static let numbers = Array("23456789")
    private static let symbols = Array("!@#$%^&*()-_=+[]{};:,.?")

    static func generate(
        length: Int,
        includeUppercase: Bool,
        includeNumbers: Bool,
        includeSymbols: Bool
    ) -> String {
        var generator = SystemRandomNumberGenerator()
        var requiredSets: [[Character]] = [lowercase]
        if includeUppercase { requiredSets.append(uppercase) }
        if includeNumbers { requiredSets.append(numbers) }
        if includeSymbols { requiredSets.append(symbols) }

        let targetLength = max(length, requiredSets.count)
        let available = requiredSets.flatMap { $0 }
        var result = requiredSets.compactMap { $0.randomElement(using: &generator) }
        while result.count < targetLength {
            if let character = available.randomElement(using: &generator) { result.append(character) }
        }
        result.shuffle(using: &generator)
        return String(result)
    }
}
