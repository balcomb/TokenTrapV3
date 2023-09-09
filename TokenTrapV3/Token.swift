//
//  Token.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 9/10/22.
//

import Foundation

struct Token: GameLogicResource {
    let id = UUID()
    var attributes: Attributes
    var isWildcard = false
    var shouldShowTrainingHint = false

    static var random: Token {
        Token(Color.allCases.randomElement()!, Icon.allCases.randomElement()!)
    }

    init(_ color: Color, _ icon: Icon) {
        attributes = Attributes(color: color, icon: icon)
    }

    init?(partialMatch pair: TokenPair) {
        guard pair.isPartialMatch else {
            return nil
        }
        let attributes1 = pair.token1.attributes
        let attributes2 = pair.token2.attributes
        let color: Token.Color?
        let icon: Token.Icon?
        if attributes1.color == attributes2.color {
            color = attributes1.color
            icon = Token.Icon.allCases.first { icon in
                icon != attributes1.icon && icon != attributes2.icon
            }
        } else {
            icon = attributes1.icon
            color = Token.Color.allCases.first { color in
                color != attributes1.color && color != attributes2.color
            }
        }
        guard let color = color, let icon = icon else {
            return nil
        }
        self.init(color, icon)
    }

    struct Attributes: Equatable {
        let color: Color
        let icon: Icon

        var partialMatches: [Attributes] {
            var possibleAttributes: [Token.Attributes] = []
            Token.Color.allCases.forEach { color in
                Token.Icon.allCases.forEach { icon in
                    let attributes = Token.Attributes(color: color, icon: icon)
                    guard isPartialMatch(for: attributes) else {
                        return
                    }
                    possibleAttributes.append(attributes)
                }
            }
            return possibleAttributes
        }

        func isPartialMatch(for attributes: Attributes) -> Bool {
            self != attributes && (color == attributes.color || icon == attributes.icon)
        }
    }

    enum Icon: String, CaseIterable, Identifiable {
        case die = "IconDie"
        case face = "IconFace"
        case star = "IconStar"

        var id: String { self.rawValue }
    }

    enum Color: String, CaseIterable {
        case blue = "TokenBlue"
        case gray = "TokenGray"
        case red = "TokenRed"
    }
}

struct TokenPair {
    let token1: Token
    let token2: Token

    var tokens: [Token] { [token1, token2] }

    var isPartialMatch: Bool {
        token1.attributes.isPartialMatch(for: token2.attributes)
    }

    init(token1: Token, token2: Token) {
        self.token1 = token1
        self.token2 = token2
    }

    init(partialMatchTarget: Token) {
        let possibleAttributes = partialMatchTarget.attributes.partialMatches
        let attributes1 = possibleAttributes.randomElement()!
        let attributes2 = possibleAttributes.first { $0.isPartialMatch(for: attributes1) }!
        token1 = Token(attributes1.color, attributes1.icon)
        token2 = Token(attributes2.color, attributes2.icon)
    }

    func canConvert(to token: Token?) -> Bool {
        guard let token = token else {
            return false
        }
        return [
            self,
            TokenPair(token1: token, token2: token1),
            TokenPair(token1: token, token2: token2)
        ].allSatisfy {
            $0.isPartialMatch
        }
    }

    func contains(_ token: Token) -> Bool {
        token == token1 || token == token2
    }
}

class TokenViewModel: GameViewModelObject {
    let token: Token
    @Published var style: Style?
    @Published var isDimmed = false
    var isWildcard: Bool { token.isWildcard }

    init(token: Token, style: Style? = nil) {
        self.token = token
        self.style = style
    }

    func update(with state: GameLogic.State, _ stateRow: GameLogic.Row, _ index: Int) {
        setStyle(with: state, stateRow, index)
        setIsDimmed(with: state, stateRow)
    }

    private func setIsDimmed(with state: GameLogic.State, _ stateRow: GameLogic.Row) {
        guard style == nil || style == .orange else {
            return
        }
        isDimmed = state.solvedRows.contains { $0?.id == stateRow.id }
        if isDimmed {
            style = nil
        }
    }

    private func shouldShowTrainingHint(for state: GameLogic.State) -> Bool {
        state.nextTrainingHintToken != token && token.shouldShowTrainingHint
    }

    private func setStyle(with state: GameLogic.State, _ stateRow: GameLogic.Row, _ index: Int) {
        let isTargetMatch = state.solvedRows.has(index, in: stateRow)
        let selection = state.selections.last
        let shouldShowTrainingHint = shouldShowTrainingHint(for: state)

        var newStyle: Style?
        if isTargetMatch {
            newStyle = .gold
        } else if let selection = selection, selection.tokens.contains(token) {
            newStyle = Style(selection.status)
        } else if shouldShowTrainingHint {
            newStyle = .orange
        }
        guard newStyle != style else {
            return
        }
        style = newStyle
    }

    enum Style {
        case gray
        case green
        case red
        case gold
        case orange

        init(_ selectionStatus: GameLogic.Selection.Status) {
            switch selectionStatus {
            case .selected:
                self = .gray
            case .rejected:
                self = .red
            case .partialMatch:
                self = .green
            case .targetMatch:
                self = .gold
            }
        }
    }
}
