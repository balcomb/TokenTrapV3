//
//  TokenView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 8/13/22.
//

import SwiftUI

struct TokenView: View {
    @ObservedObject var viewModel: TokenViewModel
    let size: CGFloat
    private var iconSize: CGFloat { size * 0.6 }
    @State var scale = 0.1

    var body: some View {
        ZStack {
            background
            if viewModel.isWildcard {
                wildcardIcon
            } else {
                icon
            }
        }
        .frame(width: size, height: size)
        .opacity(viewModel.isDimmed ? 0.7 : 1)
    }

    private var background: some View {
        Circle().foregroundColor(circleColor)
    }

    private var wildcardIcon: some View {
        Text("?")
            .font(.custom("AmericanTypewriter-Bold", fixedSize: size * 0.8))
            .foregroundColor(.wildcardPurple)
    }

    private var icon: some View {
        Image(
            viewModel.token.attributes.icon.rawValue
        )
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .foregroundColor(Color(viewModel.token.attributes.color.rawValue))
        .frame(width: iconSize, height: iconSize)
        .scaleEffect(scale)
        .onAppear {
            withAnimation {
                scale = 1
            }
        }
    }

    private var circleColor: Color {
        switch viewModel.style {
        case .green: return .tokenBackgroundGreen
        case .red: return .tokenBackgroundRed
        case .gold: return .tokenBackgroundGold
        case .gray: return .tokenBackgroundGray
        default: return .tokenBackgroundDefault
        }
    }
}
