import BackgroundTasks
import Foundation

@MainActor
final class BackgroundTaskManager {
    static let refreshIdentifier = "com.example.PhotoSpotRadar.refresh"
    private var operation: (@MainActor () async -> Void)?

    func register(operation: @escaping @MainActor () async -> Void) {
        self.operation = operation
        // The launch handler MUST run on the main queue: this class is MainActor-bound, so the
        // handler closure inherits MainActor isolation and Swift's runtime executor check traps
        // when BackgroundTasks invokes it on its private queue. With `using: nil` this crashed
        // the app on every overnight background refresh (EXC_BREAKPOINT in
        // _dispatch_assert_queue_fail on the com.apple.BGTaskScheduler queue).
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshIdentifier,
                                        using: .main) { [weak self] task in
            guard let refresh = task as? BGAppRefreshTask else { return }
            Task { @MainActor [weak self] in await self?.handle(refresh) }
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 4)
        // iOS decides if and when this runs; background refresh is opportunistic, never a timer.
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGAppRefreshTask) async {
        schedule()
        let worker = Task { await operation?() }
        task.expirationHandler = { worker.cancel() }
        await worker.value
        task.setTaskCompleted(success: !worker.isCancelled)
    }
}
