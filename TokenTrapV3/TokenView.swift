//
//  TokenView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 8/13/22.
//

import SwiftUI

struct TokenView: View {
    @ObservedObject var token: Token
    let size: CGFloat
    private var iconSize: CGFloat { size * 0.6 }
    @State var scale = 0.1

    var body: some View {
        ZStack {
            background
            icon
        }
        .frame(width: size, height: size)
    }

    private var background: some View {
        Circle().foregroundColor(circleColor)
    }

    private var icon: some View {
        Image(
            token.icon.rawValue
        )
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .foregroundColor(Color(token.color.rawValue))
        .frame(width: iconSize, height: iconSize)
        .scaleEffect(scale)
        .onAppear {
            withAnimation {
                scale = 1
            }
        }
    }

    private var circleColor: Color {
        switch token.selectionStatus {
        case .none: return .white
        case .selected: return .tokenBackgroundGreen
        case .rejected: return .tokenBackgroundRed
        case .keyMatch: return .tokenBackgroundGold
        }
    }
}
