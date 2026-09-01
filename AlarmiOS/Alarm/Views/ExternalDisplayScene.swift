//  ExternalDisplayScene.swift
//  What a connected beamer or Apple TV shows.
//
//  Without a scene of its own, iOS mirrors the whole iPad screen — dock,
//  banners, alarm and all. In a classroom that means the alarm goes to the
//  class before it goes to the colleague next door. So the external display
//  gets its own scene with a neutral picture, and the alarm stays on the iPad.
//
//  The honest limit, spelled out in the README as well: the system banner that
//  appears BEFORE anybody opens the app is drawn by iOS, and iOS mirrors it.
//  Whether lock-screen previews are switched off on teaching iPads is a
//  decision for the crisis team; no app can make it.

import SwiftUI
import UIKit

final class ExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: NeutralExternalView())
        window.isHidden = false
        self.window = window
    }
}

/// Deliberately empty of information. Not a logo, not a status, not "an alarm
/// is running" — a room full of children reads everything on a wall.
struct NeutralExternalView: View {
    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "display")
                    .font(.system(size: 96, weight: .thin))
                    .foregroundStyle(.white.opacity(0.25))
                Text("Bildschirm bereit")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}
