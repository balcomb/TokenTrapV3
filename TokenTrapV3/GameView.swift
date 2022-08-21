//
//  GameView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 8/7/22.
//

import SwiftUI

struct GameView: View {
    let settings: GameSettings
    var completion: () -> Void

    static var boardWidth: CGFloat {
        let screenWidth = UIScreen.screens.first?.bounds.size.width ?? .zero
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return screenWidth
        }
        return screenWidth * 0.666
    }

    var body: some View {
        VStack(spacing: 0) {
            topControls
            boardContainer
            bottomControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }

    private var topControls: some View {
        VStack {
            Spacer()
            Button("dismiss") { completion() }.foregroundColor(.yellow)
            Spacer()
        }
    }

    private var boardContainer: some View {
        VStack(spacing: 0) {
            GridView()
        }
        .frame(width: Self.boardWidth, height: Self.boardWidth)
        .background(Color.boardBackground)
    }

    private var bottomControls: some View {
        VStack {
            Spacer()
            Text("this is it")
            Spacer()
        }
    }
}

struct GridView: View {
    private var gridSize: Int { 8 }
    private var adjustedWidth: CGFloat { GameView.boardWidth - (2 * cellSpacing) }
    private var cellSpacing: CGFloat { 1 }
    private var cellSize: CGFloat { (adjustedWidth / CGFloat(gridSize)) - cellSpacing }

    var body: some View {
        VStack(spacing: cellSpacing) {
            fill(with: { row })
        }
        .frame(width: adjustedWidth, height: adjustedWidth)
    }

    private var row: some View {
        HStack(spacing: cellSpacing) {
            fill(with: { cell })
        }
    }

    private var cell: some View {
        Circle()
            .foregroundColor(.gridBackground)
            .frame(width: cellSize, height: cellSize)
    }

    private func fill<Content: View>(with content: @escaping () -> Content) -> some View {
        ForEach(1...gridSize, id: \.self) { _ in
            content()
        }
    }
}

struct GameSettings: Equatable {
    var skillLevel = SkillLevel.basic
    var isTrainingMode = false

    enum SkillLevel {
        case basic, expert
    }
}
