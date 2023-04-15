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
