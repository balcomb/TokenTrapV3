//
//  ContentView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 7/31/22.
//

import SwiftUI

struct MenuView: View {
    @Binding var gameSettings: GameLogic.Settings
    let action: (Coordinator.Destination) -> Void
    @State private var didAppear = false
    @State private var controlOpacity: Double = 0

    private static var logoName: String { "Logo" }
    private static var logoWidth: CGFloat { UIImage(named: logoName)?.size.width ?? 0 }

    private var openingAnimations: [SequencedAnimation] {
        [
            SequencedAnimation(duration: 0.5) {
                didAppear = true
            },
            SequencedAnimation {
                controlOpacity = 1
            }
        ]
    }

    var body: some View {
        VStack {
            logo
            if didAppear {
                controls
            }
        }
        .frame(width: Self.logoWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .onAppear {
            openingAnimations.start(delay: 1.5)
        }
    }

    private var logo: some View {
        Image(Self.logoName)
    }

    private var controls: some View {
        VStack {
            playButton
            skillLevelLabel
            skillLevelSelector
            learnHowButton
            trainingModeButton
        }
        .opacity(controlOpacity)
    }

    private var playButton: some View {
        makeButton("Play") {
            startGame()
        }
        .bigButton()
        .padding(.vertical)
    }

    private var skillLevelLabel: some View {
        Text(
            "skill level".uppercased()
        )
        .font(.caption.weight(.heavy))
        .foregroundColor(.white)
    }

    private var skillLevelSelector: some View {
        Picker("skillLevelSelector", selection: $gameSettings.skillLevel) {
            Text("Basic").tag(GameLogic.Settings.SkillLevel.basic)
            Text("Expert").tag(GameLogic.Settings.SkillLevel.expert)
        }
        .styled()
        .padding(.bottom)
    }

    private var learnHowButton: some View {
        makeSmallButton("Learn How") { action(.learnHow) }
    }

    private var trainingModeButton: some View {
        makeSmallButton("Play in Training Mode") {
            startGame(isTrainingMode: true)
        }
    }

    private func startGame(isTrainingMode: Bool = false) {
        gameSettings.isTrainingMode = isTrainingMode
        action(.game)
    }

    private func makeButton(_ text: String, action: @escaping () -> Void) -> some View {
        Button(
            action: action,
            label: {
                Spacer()
                buttonText(text)
                Spacer()
            }
        )
    }

    private func makeSmallButton(_ text: String, action: @escaping () -> Void) -> some View {
        makeButton(text, action: action)
            .smallButton()
    }
}
