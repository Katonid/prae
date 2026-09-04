//  RootView.swift
//  Which screen the app is on, and what always sits on top of it.

import Combine
import SwiftUI
import UIKit

struct RootView: View {

    @EnvironmentObject private var model: AppModel
    @State private var started = false

    var body: some View {
        content
            .fullScreenCover(isPresented: $model.showsAlarmScreen) {
                if let alarm = model.activeAlarm {
                    AlarmScreenView(alarm: alarm)
                        .environmentObject(model)
                }
            }
            // Die Bänder liegen in `Meldungen.swift`, weil sie auch über den
            // Blättern gebraucht werden — ein Fehler unter einem offenen Blatt
            // ist ein Fehler, den niemand sieht.
            .meldungen(model)
            .task {
                guard !started else { return }
                started = true
                await model.start()
            }
            // Not `onChange(of: scenePhase)`: that overload is deprecated in
            // iOS 17 while this app still builds for 16, and a notification is
            // the same thing without the version dance.
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification)) { _ in
                Task { await model.refresh() }
            }
            .onReceive(model.notifications.$pendingEvent.compactMap { $0 }) { event in
                Task {
                    await model.handle(event: event)
                    model.notifications.pendingEvent = nil
                }
            }
            .onReceive(model.notifications.$pendingAck.compactMap { $0 }) { _ in
                Task { await model.handlePendingAck() }
            }
    }

    @ViewBuilder
    private var content: some View {
        if !model.isJoined {
            JoinView()
        } else if !model.onboardingDone {
            OnboardingView()
        } else {
            HomeView()
        }
    }

}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView().environmentObject(PreviewModels.joined())
    }
}
