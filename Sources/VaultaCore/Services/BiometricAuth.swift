import Foundation
import LocalAuthentication

/// Thin wrapper around LocalAuthentication for querying biometric availability.
public enum BiometricAuth {

    public enum Kind: Sendable {
        case touchID
        case opticID
        case none

        public var displayName: String {
            switch self {
            case .touchID: return "Touch ID"
            case .opticID: return "Optic ID"
            case .none: return "device password"
            }
        }
    }

    /// What biometric hardware (if any) is enrolled and available right now.
    public static func availableKind() -> Kind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    /// True if either biometrics or a device password can authenticate the user.
    public static func canAuthenticate() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
}
