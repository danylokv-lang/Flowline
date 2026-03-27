import Foundation

/// Email validation utility used across all platforms (iOS, macOS, Web)
struct EmailValidator {

    /// Validates email format using regex pattern
    /// - Parameter email: Email string to validate
    /// - Returns: True if email format is valid, false otherwise
    static func isValid(_ email: String) -> Bool {
        let email = email.trimmingCharacters(in: .whitespaces)

        // RFC 5322 simplified pattern that catches most common cases
        // Allows: local@domain.ext format
        let pattern = "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }

        let range = NSRange(email.startIndex..., in: email)
        return regex.firstMatch(in: email, options: [], range: range) != nil
    }

    /// Provides user-friendly error message for invalid email
    static func errorMessage(for email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return "Email is required."
        }

        if !trimmed.contains("@") {
            return "Email must contain @ symbol."
        }

        if trimmed.contains(" ") {
            return "Email cannot contain spaces."
        }

        let parts = trimmed.split(separator: "@")
        if parts.count != 2 {
            return "Email must have exactly one @ symbol."
        }

        if parts[0].isEmpty {
            return "Email must have text before @."
        }

        if parts[1].isEmpty {
            return "Email must have a domain after @."
        }

        if !parts[1].contains(".") {
            return "Domain must contain a dot (example@domain.com)."
        }

        let domainParts = parts[1].split(separator: ".")
        if domainParts.last?.isEmpty ?? true || domainParts.last?.count ?? 0 < 2 {
            return "Domain extension must be at least 2 characters."
        }

        return "Please enter a valid email address."
    }
}
