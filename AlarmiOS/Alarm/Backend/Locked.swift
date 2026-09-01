//  Locked.swift
//  Taking a lock without upsetting the concurrency checker.
//
//  `NSLock.lock()` is marked `noasync`: calling it directly inside an `async`
//  function is a warning today and an error in the Swift 6 language mode. The
//  reasoning is sound — a task can suspend between `lock()` and `unlock()` and
//  resume on a different thread, and an NSLock unlocked from the wrong thread
//  is undefined behaviour.
//
//  The fix is not to drop the lock but to make the locked region a piece of
//  code that CANNOT suspend: a synchronous closure. `around` is an ordinary
//  function, so nothing inside it may await, and the compiler stops warning
//  because it can see that for itself.

import Foundation

extension NSLock {
    /// Runs `body` while holding the lock, and gives its result back.
    ///
    /// Deliberately not `async`: the whole point is that the locked region has
    /// no suspension point in it.
    func around<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
