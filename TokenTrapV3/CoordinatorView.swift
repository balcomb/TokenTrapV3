//
//  Coordinator.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 7/31/22.
//

import SwiftUI

struct CoordinatorView: View {
    @StateObject private var coordinator = Coordinator()

    var body: some View {
        NavigationView {
            menu
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $coordinator.isShowingLearnHow) {
            LearnHowView(isShowingLearnHow: $coordinator.isShowingLearnHow)
        }
        .fullScreenCover(isPresented: $coordinator.isShowingGame) {
            GameView(coordinator.settings, $coordinator.isShowingGame)
        }
    }

    private var menu: some View {
        MenuView()
            .navigationBarHidden(true)
            .environmentObject(coordinator)
    }
}

extension CoordinatorView {

    class Coordinator: ObservableObject {
        @Published fileprivate var isShowingGame = false
        @Published fileprivate var isShowingLearnHow = false

        var settings = GameLogic.Settings()

        func handle(_ destination: Destination) {
            isShowingGame = destination == .game
            isShowingLearnHow = destination == .learnHow
        }

        enum Destination {
            case game
            case learnHow
        }
    }
}
