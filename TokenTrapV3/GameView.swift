//
//  GameView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 8/7/22.
//

import SwiftUI

struct GameView: View {
    @StateObject private var viewModel = GameViewModel()
    @Binding var settings: GameLogic.Settings
    @Binding var isShowingGame: Bool

    static var boardWidth: CGFloat {
        UIScreen.main.bounds.size.width * (UIDevice.current.userInterfaceIdiom == .pad ? 0.666 : 1)
    }
    static var gridWidth: CGFloat { GameView.boardWidth - (2 * tokenSpacing) }
    static var tokenSpacing: CGFloat { 1 }
    static var tokenSize: CGFloat { (gridWidth / CGFloat(GameLogic.gridSize)) - tokenSpacing }
    private var topControlSize: CGFloat { 32 }
    private var gameOverStackSpacing: CGFloat { 20 }

    var body: some View {
        VStack(spacing: 0) {
            topControls
            timeProgressView
            boardContainer
            levelProgressView
            scoreboard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .onAppear {
            viewModel.handle(.onAppear(settings, $isShowingGame))
        }
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
        Button {
            viewModel.handle(.closeSelected)
        } label: {
            closeIcon(size: topControlSize)
        }
        .disabled(viewModel.closeButtonIsDisabled)
        .confirmationDialog(
            "Game Paused",
            isPresented: $viewModel.isShowingCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Continue Game", role: .cancel) {
                viewModel.handle(.resume)
            }
            Button("End Game", role: .destructive) {
                viewModel.handle(.closeConfirmed)
            }
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
                RowView(row: row) {
                    viewModel.handle(.selected(token: $0))
                }
            }
        }
        .frame(width: Self.gridWidth, height: Self.gridWidth)
    }

    private var scoreboard: some View {
        VStack {
            ScoreboardView(leadingText: "LEVEL", trailingText: "SCORE", style: .detail)
            ScoreboardView(leadingText: "\(viewModel.level)", trailingText: "\(viewModel.score)")
            Spacer()
        }
        .frame(width: Self.boardWidth)
        .padding(.top, 8)
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
        LevelTransitionView(level: viewModel.level, type: viewModel.auxiliaryView) {
            viewModel.handle(.levelTransition)
        }
    }

    private var playAgainButton: some View {
        Button(
            action: { viewModel.handle(.newGame) },
            label: { buttonText("Play Again").padding(.horizontal) }
        )
        .bigButton()
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
