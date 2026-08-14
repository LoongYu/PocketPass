import Foundation

@main
struct PasswordGeneratorValidation {
    static func main() {
        for length in [8, 20, 32, 64] {
            for _ in 0..<100 {
                let value = PasswordGeneratorService.generate(
                    length: length,
                    includeUppercase: true,
                    includeNumbers: true,
                    includeSymbols: true
                )
                precondition(value.count == length)
                precondition(value.contains(where: { $0.isLowercase }))
                precondition(value.contains(where: { $0.isUppercase }))
                precondition(value.contains(where: { $0.isNumber }))
                precondition(value.contains(where: { "!@#$%^&*()-_=+[]{};:,.?".contains($0) }))
            }
        }
        print("password-generator-validation-ok")
    }
}
