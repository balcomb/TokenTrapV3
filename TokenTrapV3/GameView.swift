//
//  GameView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 8/7/22.
//

import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel

    typealias EventHandler = (GameLogic.Event) -> (() -> Void)
    private var eventHandler: EventHandler {
        { event in { viewModel.handle(event) } }
    }

    static var boardWidth: CGFloat {
        UIScreen.main.bounds.size.width * (UIDevice.current.userInterfaceIdiom == .pad ? 0.666 : 1)
    }
    static var gridWidth: CGFloat { GameView.boardWidth - (2 * tokenSpacing) }
    static var tokenSpacing: CGFloat { 1 }
    static var tokenSize: CGFloat { (gridWidth / CGFloat(GameLogic.gridSize)) - tokenSpacing }
    private var topControlSize: CGFloat { 32 }
    private var gameOverStackSpacing: CGFloat { 20 }

    init(_ settings: GameLogic.Settings, _ isShowingGame: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: GameViewModel(settings, isShowingGame))
    }

    var body: some View {
        VStack(spacing: 0) {
            topControls
            timeProgressView
            boardContainer
            levelProgressView
            ScoreboardView(viewModel: viewModel.scoreboard)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .onAppear(perform: eventHandler(.gameAppeared))
    }

    private var topControls: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack {
                closeButton
                Spacer()
                targetIndicator
            }
        }
        .frame(width: Self.boardWidth)
    }

    private var closeButton: some View {
        Button(action: eventHandler(.closeSelected)) {
            closeIcon(size: topControlSize)
        }
        .disabled(viewModel.closeButtonIsDisabled)
        .confirmationDialog(
            "Game Paused",
            isPresented: $viewModel.isShowingCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Continue Game", role: .cancel, action: eventHandler(.gameResumed))
            Button("End Game", role: .destructive, action: eventHandler(.closeConfirmed))
        }
    }

    private var targetIndicator: some View {
        HStack {
            if let targetToken = viewModel.targetToken {
                GameText("TARGET  \u{25B6}", style: .detail)
                TokenView(viewModel: targetToken, size: topControlSize)
            }
        }
        .padding(.horizontal)
    }

    private var timeProgressView: some View {
        ProgressView(
            viewModel: viewModel.timeProgress,
            width: Self.boardWidth,
            style: .time
        )
    }

    private var levelProgressView: some View {
        ProgressView(
            viewModel: viewModel.levelProgress,
            width: Self.boardWidth,
            style: .level
        )
    }

    private var boardContainer: some View {
        ZStack {
            GridView()
            rows.opacity(viewModel.rowVisibility.opacity)
            auxiliaryView
        }
        .frame(width: Self.boardWidth, height: Self.boardWidth)
        .background(Color.boardBackground)
    }

    private var rows: some View {
        VStack(spacing: Self.tokenSpacing) {
            if viewModel.rows.count < GameLogic.gridSize {
                Spacer()
            }
            ForEach(viewModel.rows) { row in
                RowView(row: row, eventHandler: eventHandler)
            }
        }
        .frame(width: Self.gridWidth, height: Self.gridWidth)
    }

    private var auxiliaryView: some View {
        Group {
            switch viewModel.auxiliaryView {
            case .gameOver(let content):
                getGameOverView(with: content)
            case .levelComplete:
                levelTransitionView
            case .levelIntro:
                levelTransitionView
            default:
                EmptyView()
            }
        }
    }

    private var levelTransitionView: some View {
        LevelTransitionView(
            level: viewModel.scoreboard.level,
            type: viewModel.auxiliaryView,
            action: eventHandler(.levelTransition)
        )
    }

    private var playAgainButton: some View {
        Button(action: eventHandler(.newGame)) {
            getPlayAgainArrowText(arrowCharacter: "\u{25B6}")
            buttonText(" Play Again ")
            getPlayAgainArrowText(arrowCharacter: "\u{25C0}")
        }
        .bigButton()
        .controlSize(.large)
    }

    private func getPlayAgainArrowText(arrowCharacter: String) -> some View {
        buttonText(
            Array(repeating: arrowCharacter, count: 3).joined()
        )
        .foregroundColor(.logoBlue)
    }

    private func getGameOverView(with content: GameViewModel.GameOverContent) -> some View {
        VStack(spacing: gameOverStackSpacing) {
            Spacer()
            Spacer()
            GameText(content.headline, style: .primaryHot, alignment: .center)
            if !content.detailTextItems.isEmpty {
                getDetailTextStack(with: content.detailTextItems)
            }
            Spacer()
            playAgainButton
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func getDetailTextStack(
        with content: [String]
    ) -> some View {
        VStack(spacing: gameOverStackSpacing / 2) {
            ForEach(content, id: \.self) { item in
                GameText(item, style: .detail, alignment: .center)
            }
        }
    }
}
