//
//  ContentView.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 7/31/22.
//

import SwiftUI

struct MenuView: View {
    let action: (Coordinator.Destination) -> Void
    @State private var skillLevel = GameViewModel.Settings.SkillLevel.basic
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
            action(.game(settings: .init(skillLevel: skillLevel)))
        }
        .tint(.buttonBlue)
        .buttonStyle(.borderedProminent)
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
        Picker("skillLevelSelector", selection: $skillLevel) {
            Text("Basic").tag(GameViewModel.Settings.SkillLevel.basic)
            Text("Expert").tag(GameViewModel.Settings.SkillLevel.expert)
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
                Text(text).fontWeight(.heavy)
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
