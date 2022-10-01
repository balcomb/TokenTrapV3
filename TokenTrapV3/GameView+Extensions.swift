//
//  GameView+Extensions.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 10/1/22.
//

import SwiftUI

extension GameView {

    struct RowView: View {
        @ObservedObject var row: GameViewModel.Row
        @State private var scale = 0.7
        let action: (Token) -> Void

        var body: some View {
            HStack(spacing: GameView.tokenSpacing) {
                getTokenViews()
            }
            .scaleEffect(scale)
            .onAppear {
                withAnimation {
                    scale = 1
                }
            }
        }

        private func getTokenViews() -> some View {
            ForEach(row.tokens) { token in
                TokenView(token: token, size: GameView.tokenSize)
                    .onTapGesture {
                        action(token)
                    }
            }
        }
    }

    struct GridView: View {

        var body: some View {
            VStack(spacing: GameView.tokenSpacing) {
                fill(with: { row })
            }
            .frame(width: GameView.gridWidth, height: GameView.gridWidth)
        }

        private var row: some View {
            HStack(spacing: GameView.tokenSpacing) {
                fill(with: { cell })
            }
        }

        private var cell: some View {
            Circle()
                .foregroundColor(.gridBackground)
                .frame(width: GameView.tokenSize, height: GameView.tokenSize)
        }

        private func fill<Content: View>(with content: @escaping () -> Content) -> some View {
            ForEach(1...GameViewModel.gridSize, id: \.self) { _ in
                content()
            }
        }
    }

    struct ProgressView: View {
        private let viewModel: GameViewModel.Progress
        private let indicatorWidth: CGFloat
        private let colors: (on: Color, off: Color)

        init(viewModel: GameViewModel.Progress, width: CGFloat, style: Style) {
            self.viewModel = viewModel
            let indicatorCount = CGFloat(viewModel.indicators.count)
            indicatorWidth = (width - (IndicatorView.weight * (indicatorCount + 1))) / indicatorCount

            switch style {
            case .time:
                colors = (.green, .darkGreen)
            case .level:
                colors = (.yellow, .progressOff)
            }
        }

        var body: some View {
            HStack(spacing: IndicatorView.weight) {
                indicators
            }
            .padding(.vertical, IndicatorView.weight)
        }

        private var indicators: some View {
            ForEach(viewModel.indicators) {
                IndicatorView(viewModel: $0, width: indicatorWidth, colors: colors)
            }
        }

        enum Style {
            case time, level
        }
    }

    struct IndicatorView: View {
        @ObservedObject var viewModel: GameViewModel.Progress.Indicator
        let width: CGFloat
        let colors: (on: Color, off: Color)
        static var weight: CGFloat { 4 }

        var body: some View {
            Rectangle()
                .cornerRadius(Self.weight / 2)
                .foregroundColor(viewModel.isOn ? colors.on : colors.off)
                .frame(width: width, height: Self.weight)
        }
    }
}
