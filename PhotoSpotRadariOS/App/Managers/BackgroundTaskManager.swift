import BackgroundTasks
import Foundation

@MainActor
final class BackgroundTaskManager {
    static let refreshIdentifier = "com.example.PhotoSpotRadar.refresh"
    private var operation: (@MainActor () async -> Void)?

    func register(operation: @escaping @MainActor () async -> Void) {
        self.operation = operation
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshIdentifier, using: nil) { [weak self] task in
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
