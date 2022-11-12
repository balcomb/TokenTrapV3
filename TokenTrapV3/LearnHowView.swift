//
//  LearnHowView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 8/7/22.
//

import SwiftUI

struct LearnHowView: View {
    @Binding var isShowingLearnHow: Bool

    private static var margin: CGFloat { 24 }
    private static var tokenSize: CGFloat { 44 }
    private static var tokenSpacing: CGFloat { 5 }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            scrollView
        }
        .background(Color.background)
    }
}

// MARK: Views

extension LearnHowView {

    private var navBar: some View {
        HStack {
            navBarTitle
            Spacer()
            closeButton
        }
        .background(.white.opacity(0.3))
    }

    private var navBarTitle: some View {
        Text(
            Strings.navTitle
        )
        .font(.subheadline)
        .bold()
        .padding(.leading)
        .foregroundColor(.white)
    }

    private var closeButton: some View {
        Button {
            isShowingLearnHow = false
        } label: {
            Image(systemName: "xmark").padding()
        }
        .tint(.white)
    }

    private var scrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headline
                section1
                section2
                section3
            }
            .padding(Self.margin)
        }
    }

    private var headline: some View {
        Text(
            Strings.headline
        )
        .font(.title2.weight(.bold))
        .foregroundColor(.tokenBackgroundGold)
    }

    private var section1: some View {
        Group {
            SectionTitle(text: Strings.section1.title)
            SectionText(text: Strings.section1.body1)
            tokenGrid
        }
    }

    private var tokenGrid: some View {
        VStack(spacing: Self.tokenSpacing) {
            ForEach(Token.Icon.allCases) {
                TokenGridRow(icon: $0)
            }
        }
        .padding([.top, .leading])
    }

    private var section2: some View {
        Group {
            SectionTitle(text: Strings.section2.title)
            SectionText(text: Strings.section2.body1)
            partialMatchExample1
            SectionText(text: Strings.section2.body2)
            partialMatchExample2
        }
    }

    private var partialMatchExample1: some View {
        PartialMatchExample {
            TokenPair(Token(.gray, .face), Token(.gray, .star), text: Strings.Captions.example1_1)
            TokenPair(Token(.blue, .die), Token(.red, .die), text: Strings.Captions.example1_2)
        }
    }

    private var partialMatchExample2: some View {
        PartialMatchExample(padding: [.top, .leading]) {
            TokenPair(Token(.red, .star), Token(.gray, .star), text: Strings.Captions.example2_1)
            TokenPair(Token(.blue, .star), Token(.blue, .star), text: Strings.Captions.example2_2)
        }
    }

    private var section3: some View {
        Group {
            SectionTitle(text: Strings.section3.title)
            SectionText(text: Strings.section3.body1)
        }
    }
}

// MARK: Views Types

extension LearnHowView {

    private struct SectionText: View {
        let text: String
        var opacity: CGFloat = 0.7

        var body: some View {
            Text(
                text
            )
            .font(.body.weight(.bold))
            .foregroundColor(.white)
            .opacity(opacity)
        }
    }

    private struct SectionTitle: View {
        let text: String

        var body: some View {
            SectionText(
                text: text,
                opacity: 1
            )
            .padding(.top, margin)
            .padding(.bottom, 6)
        }
    }

    private struct TokenGridRow: View {
        let icon: Token.Icon

        var body: some View {
            TokenRow(
                tokens: Token.Color.allCases.map { Token($0, icon) }
            )
        }
    }

    private struct TokenRow: View {
        let tokens: [Token]

        var body: some View {
            HStack(spacing: tokenSpacing) {
                ForEach(tokens) {
                    TokenView(token: $0, size: LearnHowView.tokenSize, scale: 1)
                }
            }
        }
    }

    private struct TokenPair: View {
        let token1: Token
        let token2: Token
        let text: String

        init(_ token1: Token, _ token2: Token, text: String) {
            self.token1 = token1
            self.token2 = token2
            self.text = text
        }

        var body: some View {
            VStack {
                TokenRow(tokens: [token1, token2])
                Text(
                    text
                )
                .font(.caption)
                .bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: (2 * LearnHowView.tokenSize) + LearnHowView.tokenSpacing)
            }
        }
    }

    private struct PartialMatchExample<C>: View where C: View {
        let edges: Edge.Set
        let content: C

        init(padding edges: Edge.Set = .all, @ViewBuilder content: () -> C) {
            self.edges = edges
            self.content = content()
        }

        var body: some View {
            HStack(alignment: .top, spacing: LearnHowView.margin) {
                content
            }
            .padding(edges)
        }
    }
}

// MARK: Strings

extension LearnHowView {

    private enum Strings {

        static var navTitle: String {
            "Learn How"
        }

        static var headline: String {
            "TokenTrap is a challenging action-\u{2060}puzzle game requiring logical thinking under pressure"
        }

        static var section1: Section {
            .init(
                title: "1. Tokens Have an Icon and a Color",
                body1: "There are three different icons and three different colors."
            )
        }

        static var section2: Section {
            .init(
                title: "2. Change the Board by Finding Partial Matches",
                body1: "Tokens are partial matches when they have the same icon or the same color (but not both).",
                body2: "Select a side-by-side pair of tokens that is a partial match, and it becomes a full match. The full match is made by changing the property in which the tokens don't match. For example, if the tokens have the same icon but different colors, each token's color will change to a new matching color."
            )
        }

        enum Captions {
            static var example1_1: String {
                "Partial Match: Color"
            }
            static var example1_2: String {
                "Partial Match: Icon"
            }
            static var example2_1: String {
                "Selected Partial Match"
            }
            static var example2_2: String {
                "Resulting Full Match"
            }
        }

        static var section3: Section {
            .init(
                title: "3. Clear Rows",
                body1: "Each level has a target token. Create full match pairs that also match the target, and that pair's row is removed from the board."
            )
        }

        struct Section {
            let title: String
            let body1: String
            var body2: String = ""
        }
    }
}
