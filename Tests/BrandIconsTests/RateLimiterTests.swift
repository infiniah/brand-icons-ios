import Foundation
import Testing
@testable import BrandIcons

struct RateLimiterTests {
    @Test func aFullBucketLetsTheBurstThroughImmediately() async {
        let limiter = RateLimiter(requestsPerMinute: 600, burst: 3)
        let clock = ContinuousClock()

        let elapsed = await clock.measure {
            for _ in 0..<3 { await limiter.acquire() }
        }

        #expect(elapsed < .milliseconds(50))
        #expect(await limiter.availableTokens() == 0)
    }

    @Test func theCallerPastTheBurstIsMadeToWait() async {
        let limiter = RateLimiter(requestsPerMinute: 6000, burst: 1)
        let clock = ContinuousClock()

        await limiter.acquire()
        let elapsed = await clock.measure {
            await limiter.acquire()
        }

        #expect(elapsed >= .milliseconds(5))
    }

    @Test func queuedCallersWaitProgressivelyRatherThanTogether() async {
        let limiter = RateLimiter(requestsPerMinute: 6000, burst: 1)
        await limiter.acquire()

        let clock = ContinuousClock()
        let elapsed = await clock.measure {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<4 {
                    group.addTask { await limiter.acquire() }
                }
            }
        }

        #expect(elapsed >= .milliseconds(35))
    }

    @Test func theBucketRefillsOverTime() async throws {
        let limiter = RateLimiter(requestsPerMinute: 6000, burst: 5)
        for _ in 0..<5 { await limiter.acquire() }
        #expect(await limiter.availableTokens() == 0)

        try await Task.sleep(for: .milliseconds(40))

        #expect(await limiter.availableTokens() > 0)
    }

    @Test func resetRestoresTheBurst() async {
        let limiter = RateLimiter(requestsPerMinute: 60, burst: 2)
        await limiter.acquire()
        await limiter.acquire()
        #expect(await limiter.availableTokens() == 0)

        await limiter.reset()

        #expect(await limiter.availableTokens() == 2)
    }
}
