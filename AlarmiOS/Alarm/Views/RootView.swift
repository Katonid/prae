//  RootView.swift
//  Which screen the app is on, and what always sits on top of it.

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
            .overlay(alignment: .top) { problemBanner }
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

    /// A problem stays until it is dismissed.
    ///
    /// The usual four-second toast is wrong here: the messages this banner
    /// carries are things like "no Apple ID on this iPad", and that is exactly
    /// the message somebody has to still be able to read after looking up.
    @ViewBuilder
    private var problemBanner: some View {
        if let problem = model.problem {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(problem)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    model.problem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.orange.opacity(0.4)))
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView().environmentObject(PreviewModels.joined())
    }
}
