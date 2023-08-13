//
//  Coordinator.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 7/31/22.
//

import SwiftUI

struct Coordinator: View {
    @State private var gameSettings = GameLogic.Settings()
    @State private var isShowingGame = false
    @State private var isShowingLearnHow = false

    var body: some View {
        NavigationView {
            menu
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $isShowingLearnHow) {
            LearnHowView(isShowingLearnHow: $isShowingLearnHow)
        }
        .fullScreenCover(isPresented: $isShowingGame) {
            GameView(settings: $gameSettings) { isShowingGame = false }
        }
    }

    private var menu: some View {
        MenuView(gameSettings: $gameSettings) {
            handle(destination: $0)
        }
        .navigationBarHidden(true)
    }

    private func handle(destination: Destination) {
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
        case game
    }
}
