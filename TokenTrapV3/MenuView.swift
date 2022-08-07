//
//  ContentView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 7/31/22.
//

import SwiftUI

struct MenuView: View {
    let action: (Coordinator.Destination) -> Void
    @State private var skillLevel = GameSettings.SkillLevel.basic

    private static var logoName: String { "Logo" }
    private static var logoWidth: CGFloat { UIImage(named: logoName)?.size.width ?? 0 }

    var body: some View {
        VStack {
            logo
            playButton
            skillLevelLabel
            skillLevelSelector
            learnHowButton
            trainingModeButton
        }
        .frame(width: Self.logoWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }

    private var logo: some View {
        Image(Self.logoName).padding(.bottom)
    }

    private var playButton: some View {
        makeButton("Play") {
            action(.game(settings: .init(skillLevel: skillLevel)))
        }
        .tint(.buttonBlue)
        .buttonStyle(.borderedProminent)
    }

    private var skillLevelLabel: some View {
        Text(
            "skill level".uppercased()
        )
        .font(.caption)
        .fontWeight(.bold)
        .foregroundColor(.white)
        .padding(.top)
    }

    private var skillLevelSelector: some View {
        Picker("skillLevelSelector", selection: $skillLevel) {
            Text("Basic").tag(GameSettings.SkillLevel.basic)
            Text("Expert").tag(GameSettings.SkillLevel.expert)
        }
        .styled()
        .padding(.bottom)
    }

    private var learnHowButton: some View {
        makeSmallButton("Learn How") { action(.learnHow) }
    }

    private var trainingModeButton: some View {
        makeSmallButton("Play in Training Mode") {
            action(.game(settings: .init(skillLevel: skillLevel, isTrainingMode: true)))
        }
    }

    private func makeButton(_ text: String, action: @escaping () -> Void) -> some View {
        Button(
            action: { action() },
            label: {
                Spacer()
                Text(text).bold()
                Spacer()
            }
        )
        .buttonBorderShape(.roundedRectangle)
    }

    private func makeSmallButton(_ text: String, action: @escaping () -> Void) -> some View {
        makeButton(
            text,
            action: action
        )
        .controlSize(.small)
        .tint(.logoBlue)
        .buttonStyle(.bordered)
        .foregroundColor(.white)
    }
}
