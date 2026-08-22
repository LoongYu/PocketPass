import PocketPassCore

enum PasswordGeneratorService {
    static func generate(length: Int, includeUppercase: Bool, includeNumbers: Bool, includeSymbols: Bool) -> String {
        PasswordGenerator.generate(length: length, includeUppercase: includeUppercase, includeNumbers: includeNumbers, includeSymbols: includeSymbols)
    }
}
