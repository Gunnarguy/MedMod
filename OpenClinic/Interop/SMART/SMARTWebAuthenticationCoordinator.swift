import AuthenticationServices

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class SMARTWebAuthenticationCoordinator: NSObject {
    private var session: ASWebAuthenticationSession?

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let authenticationSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                self.session = nil

                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                    return
                }

                if let error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                continuation.resume(throwing: CancellationError())
            }

            authenticationSession.presentationContextProvider = self
            authenticationSession.prefersEphemeralWebBrowserSession = false
            session = authenticationSession

            if !authenticationSession.start() {
                session = nil
                continuation.resume(throwing: SMARTConnectionControllerError.authenticationSessionFailed)
            }
        }
    }
}

extension SMARTWebAuthenticationCoordinator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let anchor = windowScenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        if let anchor {
            return anchor
        }

        if let windowScene = windowScenes.first {
            return UIWindow(windowScene: windowScene)
        }

        preconditionFailure("No active UIWindowScene available for SMART authentication")
        #else
        return ASPresentationAnchor()
        #endif
    }
}
