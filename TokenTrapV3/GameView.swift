//
//  GameView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 8/7/22.
//

import SwiftUI

struct GameView: View {
    @StateObject var viewModel = GameViewModel()
    let settings: GameViewModel.Settings
    let completion: () -> Void

    static var boardWidth: CGFloat {
        UIScreen.main.bounds.size.width * (UIDevice.current.userInterfaceIdiom == .pad ? 0.666 : 1)
    }
    static var gridWidth: CGFloat { GameView.boardWidth - (2 * tokenSpacing) }
    static var tokenSpacing: CGFloat { 1 }
    static var tokenSize: CGFloat { (gridWidth / CGFloat(GameLogic.gridSize)) - tokenSpacing }
    private var topControlSize: CGFloat { 32 }

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
            viewModel.settings = settings
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(750)) {
                viewModel.startNewGame()
            }
        }
    }

    private var topControls: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack {
                pauseButton
                Spacer()
                targetIndicator
            }
        }
        .frame(width: Self.boardWidth)
    }

    private var pauseButton: some View {
        Button {
            completion()
        } label: {
            Image(systemName: "pause.circle")
                .resizable()
                .tint(.white)
                .frame(width: topControlSize, height: topControlSize)
                .padding()
        }
    }

    private var targetIndicator: some View {
        HStack {
            if let keyToken = viewModel.keyToken {
                GameText("TARGET  \u{25B6}", style: .detail)
                TokenView(token: keyToken, size: topControlSize)
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
        let gridOpacity = viewModel.gameStatus == .gameOver ? 0.3 : 1
        let rowOpacity = viewModel.gameStatus == .active ? 1 : 0.7
        return ZStack {
            GridView().opacity(gridOpacity)
            switch viewModel.gameStatus {
            case .gameOver: gameOverView
            case .levelBegin: levelBeginView
            case .levelComplete: levelCompleteView
            default: rows.opacity(rowOpacity)
            }
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
                    viewModel.handleTap(token: $0, in: row)
                }
            }
        }
        .frame(width: Self.gridWidth, height: Self.gridWidth)
    }

    private var levelBeginView: some View {
        VStack {
            GameText("Begin Level \(viewModel.level)")
            GameText("\(viewModel.levelCountdown)", style: .primaryHot)
        }
    }

    private var levelCompleteView: some View {
        GameText("Level Complete")
    }

    private var gameOverView: some View {
        VStack {
            GameText("Game Over", style: .primaryHot)
            Button("new game") { viewModel.startNewGame() }.foregroundColor(.tokenBackgroundGold)
        }
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
}
