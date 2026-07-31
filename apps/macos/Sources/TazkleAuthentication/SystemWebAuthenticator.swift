import AppKit
@preconcurrency import AuthenticationServices
import Foundation

@MainActor
final class SystemWebAuthenticator: NSObject,
    ASWebAuthenticationPresentationContextProviding
{
    private var session: ASWebAuthenticationSession?

    func authenticate(using request: AuthorizationRequest) async throws -> URL {
        try await authenticate(
            url: request.url,
            callbackScheme: request.callbackScheme
        )
    }

    func authenticate(
        url: URL,
        callbackScheme: String
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let completion = WebAuthenticationCompletion(continuation)
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme,
                completionHandler: Self.callbackHandler(
                    owner: self,
                    completion: completion
                )
            )
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session

            guard session.start() else {
                self.session = nil
                completion.resume(
                    .failure(AuthenticationFailure.providerUnavailable)
                )
                return
            }
        }
    }

    nonisolated private static func callbackHandler(
        owner: SystemWebAuthenticator,
        completion: WebAuthenticationCompletion
    ) -> @Sendable (URL?, (any Error)?) -> Void {
        { [weak owner] callbackURL, error in
            let result: Result<URL, any Error>
            if let authenticationError = error as? ASWebAuthenticationSessionError,
               authenticationError.code == .canceledLogin {
                result = .failure(AuthenticationFailure.cancelled)
            } else if error != nil {
                result = .failure(AuthenticationFailure.providerUnavailable)
            } else if let callbackURL {
                result = .success(callbackURL)
            } else {
                result = .failure(
                    AuthenticationFailure.invalidAuthorizationResponse
                )
            }

            completion.resume(result)
            Task { @MainActor [weak owner] in
                owner?.session = nil
            }
        }
    }

    func cancel() {
        session?.cancel()
        session = nil
    }

    func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first
            ?? ASPresentationAnchor()
    }
}

private final class WebAuthenticationCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, any Error>?

    init(_ continuation: CheckedContinuation<URL, any Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<URL, any Error>) {
        let pending = lock.withLock {
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(with: result)
    }
}
