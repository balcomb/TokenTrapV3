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
    static var tokenSize: CGFloat { (gridWidth / CGFloat(GameViewModel.gridSize)) - tokenSpacing }

    var body: some View {
        VStack(spacing: 0) {
            topControls
            timeProgressView
            boardContainer
            levelProgressView
            bottomControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .onAppear {
            viewModel.settings = settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                viewModel.startLevel()
            }
        }
    }

    private var topControls: some View {
        VStack {
            Spacer()
            Button("dismiss") { completion() }.foregroundColor(.yellow)
            Spacer()
        }
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
            rows
        }
        .frame(width: Self.boardWidth, height: Self.boardWidth)
        .background(Color.boardBackground)
    }

    private var rows: some View {
        VStack(spacing: Self.tokenSpacing) {
            if viewModel.rows.count < GameViewModel.gridSize {
                Spacer()
            }
            ForEach(viewModel.rows) { row in
                RowView(row: row) {
                    viewModel.handleTap(token: $0)
                }
            }
        }
        .frame(width: Self.gridWidth, height: Self.gridWidth)
    }

    private var bottomControls: some View {
        VStack {
            Spacer()
            Text("this is it")
            Spacer()
        }
    }
}
