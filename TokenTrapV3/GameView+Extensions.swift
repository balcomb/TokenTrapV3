//
//  GameView+Extensions.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 10/1/22.
//

import SwiftUI

extension GameView {

    struct GameText: View {
        private let content: String
        private let style: Style

        private var color: Color {
            switch style {
            case .primary, .detail: return .white
            case .primaryHot: return .tokenBackgroundGold
            }
        }

        private var font: Font {
            switch style {
            case .primary, .primaryHot: return .largeTitle
            case .detail: return .callout
            }
        }

        init(_ content: String, style: Style = .primary) {
            self.content = content
            self.style = style
        }

        var body: some View {
            Text(content)
                .font(font)
                .fontWeight(.heavy)
                .foregroundColor(color)
                .id(content) // hack for getting animations right on iOS 15
        }

        enum Style {
            case primary
            case primaryHot
            case detail
        }
    }

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
            ForEach(1...GameLogic.gridSize, id: \.self) { _ in
                content()
            }
        }
    }

    struct ProgressView: View {
        @ObservedObject private var viewModel: GameViewModel.Progress
        @State private var flashColor: Color?
        private let style: Style
        private let indicatorWidth: CGFloat
        private let weight: CGFloat

        private var colors: (on: Color, off: Color) {
            switch style {
            case .time:
                return (.green, .darkGreen)
            case .level:
                return (.tokenBackgroundGold, .progressOff)
            }
        }

        init(viewModel: GameViewModel.Progress, width: CGFloat, style: Style) {
            self.viewModel = viewModel
            self.style = style
            weight = 4
            let indicatorCount = CGFloat(viewModel.count)
            indicatorWidth = (width - (weight * (indicatorCount + 1))) / indicatorCount
        }

        var body: some View {
            HStack(spacing: weight) {
                indicators
            }
            .padding(.vertical, weight)
        }

        private var indicators: some View {
            ForEach(0 ..< viewModel.count, id: \.self) { index in
                Rectangle()
                    .cornerRadius(weight / 2)
                    .foregroundColor(getColor(at: index))
                    .frame(width: indicatorWidth, height: weight)
            }
        }

        private func getColor(at index: Int) -> Color {
            if let flashColor = flashColor {
                return flashColor
            }
            var color = colors.on
            switch viewModel.status {
            case .active(let value):
                if index >= value { color = colors.off }
            case .warning:
                color = .red
            case .flash(let completion):
                if index == 0 { flash(color: color, with: completion) }
            }
            return color
        }

        private func flash(color: Color?, count: Int = 0, with completion: @escaping () -> Void) {
            guard count < 11 else {
                completion()
                flashColor = nil
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) {
                flashColor = [colors.on, colors.off].first { $0 != color }
                flash(color: flashColor, count: count + 1, with: completion)
            }
        }

        enum Style {
            case time, level
        }
    }

    struct ScoreboardView: View {
        let leadingText: String
        let trailingText: String
        var style = GameText.Style.primary

        var body: some View {
            HStack {
                GameText(leadingText, style: style)
                Spacer()
                GameText(trailingText, style: style)
            }
            .opacity(style == .detail ? 0.7 : 1)
            .padding(.horizontal)
        }
    }

    struct LevelCountdownView: View {
        @State private var scale = 1.0
        @State private var message = " " // whitespace keeps layout consistent
        @State private var needsCompletion = true
        @State private var animationControl: SequencedAnimation.Control?
        let level: Int
        let completion: () -> Void

        private var messages: [String] { ["Ready", "Set", "GO!"] }

        private var animations: [SequencedAnimation] {
            messages.map { currentMessage in
                SequencedAnimation(
                    duration: 0.4,
                    delay: currentMessage == messages.last ? 0.8 : 0.6
                ) {
                    message = currentMessage
                }
            }
        }

        var body: some View {
            VStack {
                Spacer()
                GameText("Begin Level \(level)")
                GameText("\(message)", style: .primaryHot)
                Spacer()
                skipButton
            }
            .scaleEffect(scale)
            .onAppear {
                startAnimations()
            }
        }

        private var skipButton: some View {
            Button {
                callCompletion(animationControl)
            } label: {
                GameText("SKIP", style: .detail)
                    .padding()
            }
            .padding(.bottom)
        }

        private func startAnimations() {
            animationControl = animations.start(delay: 1) {
                callCompletion()
            }
        }

        private func callCompletion(_ animationControl: SequencedAnimation.Control? = nil) {
            guard needsCompletion else {
                return
            }
            needsCompletion = false
            animationControl?.cancel()
            [SequencedAnimation { scale = 0 }].start {
                completion()
            }
        }
    }
}
