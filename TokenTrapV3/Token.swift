//
//  Token.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 9/10/22.
//

import Foundation

class Token {
    var attributes: Attributes
    var status: Status?

    static var random: Token {
        Token(Color.allCases.randomElement()!, Icon.allCases.randomElement()!)
    }

    init(_ color: Color, _ icon: Icon, status: Status? = nil) {
        self.attributes = Attributes(color: color, icon: icon)
        self.status = status
    }

    convenience init?(partialMatch pair: TokenPair) {
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

    enum Status {
        case selected
        case rejected
        case targetMatch
    }
}

struct TokenPair {
    let token1: Token
    let token2: Token

    var isPartialMatch: Bool {
        guard token1.attributes != token2.attributes else {
            return false
        }
        return token1.attributes.color == token2.attributes.color
            || token1.attributes.icon == token2.attributes.icon
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
        token === token1 || token === token2
    }

    func set(status: Token.Status?) {
        token1.status = status
        token2.status = status
    }
}

class TokenViewModel: GameViewModelObject {
    let token: Token
    @Published var style: Style?
    @Published var isDimmed = false

    init(token: Token) {
        self.token = token
        setStyle()
    }

    func setIsDimmed(rowIsSolved: Bool) {
        let isDimmed = rowIsSolved && token.status == nil
        guard self.isDimmed != isDimmed else {
            return
        }
        self.isDimmed = isDimmed
    }

    func setStyle() {
        let newStyle = Style(tokenStatus: token.status)
        guard newStyle != style else {
            return
        }
        style = newStyle
    }

    enum Style {
        case green
        case red
        case gold

        init?(tokenStatus: Token.Status?) {
            switch tokenStatus {
            case .selected: self = .green
            case .rejected: self = .red
            case .targetMatch: self = .gold
            default: return nil
            }
        }
    }
}

extension Array where Element == Token {

    func contains(_ token: Token) -> Bool {
        contains { $0 === token }
    }

    func set(status: Token.Status?) {
        forEach {
            $0.status = status
        }
    }
}
