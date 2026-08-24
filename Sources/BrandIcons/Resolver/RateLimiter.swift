import Foundation

/// A token bucket, in requests per minute, that callers await before touching the network.
///
/// ```swift
/// await limiter.acquire()
/// let candidates = try await provider.candidates(for: query)
/// ```
///
/// Callers that arrive with the bucket empty are queued rather than spun on: each one takes
/// its token immediately, driving the balance negative, and then sleeps exactly as long as it
/// takes the bucket to refill that far. Because the balance is claimed before the sleep, two
/// callers arriving together wait different lengths instead of waking to fight over one token.
public actor RateLimiter {
    private let capacity: Double
    private let refillPerSecond: Double
    private let clock = ContinuousClock()
    private var tokens: Double
    private var lastRefill: ContinuousClock.Instant

    /// - Parameters:
    ///   - requestsPerMinute: The sustained rate.
    ///   - burst: How many requests may be spent at once after an idle spell. Defaults to one
    ///     minute's worth, so an idle limiter does not hold back the first batch.
    public init(requestsPerMinute: Int, burst: Int? = nil) {
        let rate = Double(max(1, requestsPerMinute))
        self.capacity = Double(max(1, burst ?? Int(rate)))
        self.refillPerSecond = rate / 60
        self.tokens = capacity
        self.lastRefill = ContinuousClock().now
    }

    /// Returns once this caller is allowed to proceed.
    ///
    /// Returns immediately if the task is cancelled, leaving it to the work being rate limited
    /// to report the cancellation.
    public func acquire() async {
        let wait = claimToken()
        guard wait > 0 else { return }
        try? await Task.sleep(for: .seconds(wait))
    }

    /// Tokens currently spendable without waiting.
    public func availableTokens() -> Int {
        refill()
        return max(0, Int(tokens.rounded(.down)))
    }

    /// Refills the bucket and returns the balance to full.
    public func reset() {
        tokens = capacity
        lastRefill = clock.now
    }

    /// Takes a token and reports how long the caller must wait to have earned it.
    private func claimToken() -> Double {
        refill()
        tokens -= 1
        guard tokens < 0 else { return 0 }
        return -tokens / refillPerSecond
    }

    private func refill() {
        let now = clock.now
        let elapsed = Self.seconds(from: lastRefill, to: now)
        lastRefill = now
        guard elapsed > 0 else { return }
        tokens = min(capacity, tokens + elapsed * refillPerSecond)
    }

    private static func seconds(from start: ContinuousClock.Instant, to end: ContinuousClock.Instant) -> Double {
        let components = (end - start).components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
