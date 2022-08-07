//
//  Coordinator.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 7/31/22.
//

import SwiftUI

struct Coordinator: View {
    @State private var isShowingGame = false
    @State private var isShowingLearnHow = false

    @State private var gameSettings = GameSettings()

    var body: some View {
        NavigationView {
            menu
        }
        .sheet(isPresented: $isShowingLearnHow) {
            LearnHowView()
        }
        .fullScreenCover(isPresented: $isShowingGame) {
            GameView(settings: gameSettings) { isShowingGame = false }
        }
    }

    private var menu: some View {
        MenuView {
            handle(destination: $0)
        }
        .navigationBarHidden(true)
    }

    private func handle(destination: Destination) {
        if case .game(let settings) = destination {
            gameSettings = settings
        }
        setPresentation(with: destination)
    }

    private func setPresentation(with destination: Destination) {
        isShowingGame = false
        isShowingLearnHow = false
        switch destination {
        case .learnHow:
            isShowingLearnHow = true
        case .game:
            isShowingGame = true
        }
    }
}

extension Coordinator {
    enum Destination: Equatable {
        case learnHow
        case game(settings: GameSettings)
    }
}
