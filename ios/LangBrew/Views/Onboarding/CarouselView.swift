import SwiftUI

/// C0-C5 -- Educational carousel explaining the science behind LangBrew.
/// Each page has: top nav (back + Skip), content area, bottom dots + CTA.
struct CarouselView: View {
    let onComplete: () -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    private let pageCount = 6

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top nav
                OnboardingNav(
                    showBack: true,
                    rightLabel: "Skip",
                    onBack: {
                        if currentPage > 0 {
                            withAnimation { currentPage -= 1 }
                        } else {
                            dismiss()
                        }
                    },
                    onRight: onSkip
                )

                ZStack(alignment: .topTrailing) {
                    // C0 ripple circles — placed outside TabView to avoid clipping
                    if currentPage == 0 {
                        C0RippleCircles()
                            .offset(x: 60, y: -30)
                    }

                    VStack(spacing: 0) {
                        // Pages
                        TabView(selection: $currentPage) {
                            CarouselC0Science()
                                .tag(0)
                            CarouselC1Reading()
                                .tag(1)
                            CarouselC2Level()
                                .tag(2)
                            CarouselC3Interests()
                                .tag(3)
                            CarouselC4Remember()
                                .tag(4)
                            CarouselC5Talk()
                                .tag(5)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))

                        // Bottom section
                        VStack(spacing: LBTheme.Spacing.lg) {
                            CarouselDots(count: pageCount, activeIndex: currentPage)

                            OnboardingCTA(
                                currentPage == 5 ? "Set up my plan" : "Next"
                            ) {
                                if currentPage < pageCount - 1 {
                                    withAnimation { currentPage += 1 }
                                } else {
                                    onComplete()
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, LBTheme.Spacing.md)
                    }
                }
            }
        }
    }
}

// MARK: - C0: Ripple Circles (rendered outside TabView to avoid clipping)

private struct C0RippleCircles: View {
    var body: some View {
        ZStack {
            ForEach(Array([340, 480, 640, 820].enumerated()), id: \.offset) { index, radius in
                Circle()
                    .stroke(Color.lbG300.opacity([0.5, 0.35, 0.22, 0.12][index]), lineWidth: [1.2, 1.2, 1.0, 1.0][index])
                    .frame(width: CGFloat(radius), height: CGFloat(radius))
            }
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
    }
}

// MARK: - C0: The Science

private struct CarouselC0Science: View {
    var body: some View {
        VStack(spacing: 0) {
            // Text content, centered vertically
            VStack(spacing: LBTheme.Spacing.md) {
                Spacer()

                Text("You don't learn\na language.\nYou acquire it.")
                        .font(LBTheme.serifFont(size: 32))
                        .foregroundStyle(Color.lbBlack)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Text("When you understand real messages \u{2014} stories, conversations, ideas \u{2014} your brain acquires the language naturally. No memorisation required.")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 320)

                Spacer()
            }
            .padding(.horizontal, 30)

            // Citation
            Text("BACKED BY 40 YEARS OF RESEARCH")
                .font(.system(size: 11, weight: .regular))
                .tracking(0.8)
                .foregroundStyle(Color.lbG300)
                .textCase(.uppercase)
                .padding(.bottom, LBTheme.Spacing.sm)
        }
    }
}

// MARK: - C1: Real Reading

private struct CarouselC1Reading: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: LBTheme.Spacing.sm) {
                Text("Real reading.\nNot drills.")
                    .font(LBTheme.serifFont(size: 28))
                    .foregroundStyle(Color.lbBlack)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("You learn a language by understanding it \u{2014} not by tapping tiles.")
                    .font(LBTheme.Typography.body)
                    .foregroundStyle(Color.lbG500)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.top, LBTheme.Spacing.xxl)

            Spacer()

            // Overlapping cards
            ZStack {
                // Back card (drills, faded)
                VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.lbG200)
                                .frame(width: [70, 55, 65][row], height: 24)
                            Rectangle()
                                .fill(Color.lbG300)
                                .frame(height: 1.5)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.lbG200)
                                .frame(width: [60, 75, 50][row], height: 24)
                        }
                    }
                    Text("Memorise parts")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lbG400)
                        .italic()
                        .padding(.top, LBTheme.Spacing.xs)
                }
                .padding(20)
                .frame(width: 250)
                .background(Color.lbG50)
                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                        .strokeBorder(Color.lbG200, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                }
                .opacity(0.45)
                .rotationEffect(.degrees(-2))
                .offset(x: -15, y: -40)

                // Front card (real reading)
                VStack(alignment: .leading, spacing: 6) {
                    // Level pill
                    Text("A2")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.lbG500)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.lbG50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Passage text with highlights
                    c1PassageText
                        .font(.custom("Georgia", size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                        .lineSpacing(5)

                    Text("Understand the whole")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.lbG500)
                        .padding(.top, LBTheme.Spacing.xs)
                }
                .padding(20)
                .frame(width: 250, alignment: .leading)
                .background(Color.lbWhite)
                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                        .strokeBorder(Color.lbG200, lineWidth: 1.5)
                }
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
                .rotationEffect(.degrees(1))
                .offset(x: 15, y: 20)
            }
            .frame(height: 320)

            Spacer()
        }
        .padding(.horizontal, 30)
    }

    private var c1PassageText: Text {
        let a: Text = Text("Mar\u{00ED}a se despierta ")
        let b: Text = Text(highlightedWord("temprano"))
            .foregroundColor(Color.lbNearBlack)
        let c: Text = Text(" cada s\u{00E1}bado. Ella camina al ")
        let d: Text = Text(highlightedWord("mercado"))
            .foregroundColor(Color.lbNearBlack)
        let e: Text = Text(" con su bolsa grande y compra frutas frescas.")
        return a + b + c + d + e
    }
}

// MARK: - C2: Your Level

private struct CarouselC2Level: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: LBTheme.Spacing.sm) {
                Text("Tuned to\nyour level.")
                    .font(LBTheme.serifFont(size: 28))
                    .foregroundStyle(Color.lbBlack)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("We give you content just beyond what you know, the sweet spot for learning.")
                    .font(LBTheme.Typography.body)
                    .foregroundStyle(Color.lbG500)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.top, LBTheme.Spacing.xxl)

            Spacer()

            // Vertical gauge
            HStack(alignment: .top, spacing: LBTheme.Spacing.md) {
                // Vertical line with dot
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Line
                        Rectangle()
                            .fill(Color.lbG100)
                            .frame(width: 2)
                            .clipShape(RoundedRectangle(cornerRadius: 1))
                            .frame(maxHeight: .infinity)
                            .padding(.vertical, LBTheme.Spacing.sm)

                        // Dot at center
                        Circle()
                            .fill(Color.lbBlack)
                            .frame(width: 10, height: 10)
                            .position(x: 1, y: geometry.size.height / 2)
                    }
                    .frame(width: 10)
                }
                .frame(width: 10)

                // Level blocks
                VStack(spacing: 10) {
                    // Too easy
                    C2Block(
                        text: "Le chat est petit.",
                        label: "Too easy",
                        isFaded: true,
                        isActive: false
                    )

                    // Your level (active)
                    C2Block(
                        text: nil,
                        label: "Your level \u{2190}",
                        isFaded: false,
                        isActive: true
                    )

                    // Too hard
                    C2Block(
                        text: "L'\u{00E9}pist\u{00E9}mologie contemporaine remet en question les fondements\u{2026}",
                        label: "Too hard",
                        isFaded: true,
                        isActive: false
                    )
                }
            }
            .frame(maxWidth: 320)
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

private struct C2Block: View {
    let text: String?
    let label: String
    let isFaded: Bool
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isActive {
                // Active block with vocab highlights
                c2ActiveText
                    .font(.custom("Georgia", size: 13))
                    .foregroundStyle(Color.lbNearBlack)
                    .lineSpacing(3)
            } else if let text {
                Text(text)
                    .font(.custom("Georgia", size: 13))
                    .foregroundStyle(isFaded ? Color.lbG300 : Color.lbNearBlack)
                    .lineSpacing(3)
            }

            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Color.lbBlack : Color.lbG400)
                .italic(!isActive)
        }
        .padding(.horizontal, LBTheme.Spacing.lg)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                .strokeBorder(
                    isActive ? Color.lbBlack : Color.lbG100,
                    lineWidth: 1.5
                )
        }
        .opacity(isFaded ? 0.5 : 1)
        .scaleEffect(isActive ? 1.03 : 1.0)
        .shadow(color: isActive ? Color.lbBlack.opacity(0.06) : .clear, radius: isActive ? 3 : 0)
    }

    private var c2ActiveText: Text {
        let a: Text = Text("Marie se ")
        let b: Text = Text(highlightedWord("prom\u{00E8}ne"))
            .foregroundColor(Color.lbNearBlack)
        let c: Text = Text(" dans le quartier ancien, ")
        let d: Text = Text(highlightedWord("admirant"))
            .foregroundColor(Color.lbNearBlack)
        let e: Text = Text(" les fa\u{00E7}ades color\u{00E9}es.")
        return a + b + c + d + e
    }
}

// MARK: - C3: Your Interests

private struct CarouselC3Interests: View {
    private let pills: [(emoji: String, label: String, isSelected: Bool)] = [
        ("\u{2708}\u{FE0F}", "Travel", true),
        ("\u{2600}\u{FE0F}", "Daily Life", false),
        ("\u{1F373}", "Food", true),
        ("\u{1F4BB}", "Tech", false),
        ("\u{1F4DC}", "History", true),
        ("\u{1F4D6}", "Fiction", true),
        ("\u{1F3B5}", "Music", false),
        ("\u{26BD}", "Sports", true),
        ("\u{1F52C}", "Science", false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: LBTheme.Spacing.sm) {
                Text("About what\nyou love.")
                    .font(LBTheme.serifFont(size: 28))
                    .foregroundStyle(Color.lbBlack)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Pick your interests, and every passage is written for you.")
                    .font(LBTheme.Typography.body)
                    .foregroundStyle(Color.lbG500)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.top, LBTheme.Spacing.xxl)

            Spacer()

            // Interest pills
            OnboardingFlowLayout(spacing: LBTheme.Spacing.sm) {
                ForEach(pills, id: \.label) { pill in
                    Text("\(pill.emoji) \(pill.label)")
                        .font(.system(size: 13, weight: pill.isSelected ? .medium : .regular))
                        .foregroundStyle(pill.isSelected ? Color.lbWhite : Color.lbNearBlack)
                        .padding(.horizontal, 14)
                        .padding(.vertical, LBTheme.Spacing.sm)
                        .background(pill.isSelected ? Color.lbBlack : Color.lbG50)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            if !pill.isSelected {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.lbG100, lineWidth: 1.5)
                            }
                        }
                }
            }
            .frame(maxWidth: 320)
            .padding(.bottom, 20)

            // Flow lines (decorative)
            C3FlowLines()
                .frame(width: 200, height: 50)
                .padding(.bottom, LBTheme.Spacing.lg)

            // Passage cards
            HStack(spacing: 10) {
                C3PassageCard(
                    title: "A Trip to Barcelona",
                    pills: ["\u{2708}\u{FE0F} Travel", "A2"]
                )
                C3PassageCard(
                    title: "The History of Chocolate",
                    pills: ["\u{1F4DC} History", "\u{1F373} Food", "B1"]
                )
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

private struct C3FlowLines: View {
    var body: some View {
        Canvas { context, size in
            let path1 = Path { p in
                p.move(to: CGPoint(x: 40, y: 0))
                p.addCurve(
                    to: CGPoint(x: 100, y: 50),
                    control1: CGPoint(x: 40, y: 25),
                    control2: CGPoint(x: 70, y: 40)
                )
            }
            let path2 = Path { p in
                p.move(to: CGPoint(x: 100, y: 0))
                p.addCurve(
                    to: CGPoint(x: 100, y: 50),
                    control1: CGPoint(x: 100, y: 20),
                    control2: CGPoint(x: 100, y: 35)
                )
            }
            let path3 = Path { p in
                p.move(to: CGPoint(x: 160, y: 0))
                p.addCurve(
                    to: CGPoint(x: 100, y: 50),
                    control1: CGPoint(x: 160, y: 25),
                    control2: CGPoint(x: 130, y: 40)
                )
            }
            let style = StrokeStyle(lineWidth: 1.5, dash: [4, 6])
            context.stroke(path1, with: .color(Color.lbG300), style: style)
            context.stroke(path2, with: .color(Color.lbG300), style: style)
            context.stroke(path3, with: .color(Color.lbG300), style: style)
        }
    }
}

private struct C3PassageCard: View {
    let title: String
    let pills: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            Text(title)
                .font(.custom("Georgia", size: 13).weight(.medium))
                .foregroundStyle(Color.lbNearBlack)
                .lineSpacing(2)

            OnboardingFlowLayout(spacing: 4) {
                ForEach(pills, id: \.self) { pill in
                    Text(pill)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.lbG500)
                        .padding(.horizontal, LBTheme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.lbG50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                .strokeBorder(Color.lbG100, lineWidth: 1.5)
        }
    }
}

// MARK: - C4: Remember Everything

private struct CarouselC4Remember: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: LBTheme.Spacing.sm) {
                Text("Remember\neverything.")
                    .font(LBTheme.serifFont(size: 28))
                    .foregroundStyle(Color.lbBlack)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Words come back just before you'd forget them.")
                    .font(LBTheme.Typography.body)
                    .foregroundStyle(Color.lbG500)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.top, LBTheme.Spacing.xxl)

            Spacer()

            // Forgetting curve chart
            C4ForgettingCurve()
                .frame(width: 300, height: 180)
                .padding(.bottom, LBTheme.Spacing.md)

            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Color.lbG200)
                        .frame(width: 20, height: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                    Text("Without review")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.lbG300)
                }
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Color.lbBlack)
                        .frame(width: 20, height: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                    Text("With langbrew")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.lbBlack)
                }
            }
            .padding(.bottom, 18)

            // Mini flashcard
            VStack(spacing: 4) {
                Text("mercado")
                    .font(.custom("Georgia", size: 20))
                    .foregroundStyle(Color.lbNearBlack)
                Text("market")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG400)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LBTheme.Spacing.lg)
            .background(Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                    .strokeBorder(Color.lbG100, lineWidth: 1.5)
            }
            .padding(.horizontal, 60)
            .padding(.bottom, LBTheme.Spacing.sm)

            // Progress dots
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(i < 3 ? Color.lbBlack : Color.lbG200)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 10)

            Text("From your reading, straight to your review deck.")
                .font(.system(size: 13))
                .foregroundStyle(Color.lbG500)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

private struct C4ForgettingCurve: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Y-axis labels
            let labelFont = Font.system(size: 9, weight: .medium)
            context.draw(Text("100%").font(labelFont).foregroundColor(Color.lbG400),
                         at: CGPoint(x: 18, y: 30), anchor: .center)
            context.draw(Text("0%").font(labelFont).foregroundColor(Color.lbG400),
                         at: CGPoint(x: 14, y: h - 22), anchor: .center)
            context.draw(Text("Time \u{2192}").font(labelFont).foregroundColor(Color.lbG400),
                         at: CGPoint(x: w - 25, y: h - 8), anchor: .center)

            // Forgetting curve (dashed, steep decline)
            var forgetting = Path()
            forgetting.move(to: CGPoint(x: 40, y: 25))
            forgetting.addCurve(
                to: CGPoint(x: w - 25, y: h - 30),
                control1: CGPoint(x: 80, y: 75),
                control2: CGPoint(x: 170, y: h - 48)
            )
            context.stroke(forgetting,
                           with: .color(Color.lbG200),
                           style: StrokeStyle(lineWidth: 2, dash: [6, 4]))

            // Shaded area fill
            var shaded = Path()
            // Retention curve path
            let retentionPoints: [(CGFloat, CGFloat)] = [
                (40, 25), (50, 40), (58, 52), (67, 60),
                (67, 26), (77, 40), (90, 52), (104, 57),
                (104, 26), (114, 36), (132, 44), (147, 49),
                (147, 26), (162, 34), (180, 40), (201, 44),
                (201, 26), (218, 32), (242, 36), (257, 38),
                (257, 26), (275, 28),
            ]
            shaded.move(to: CGPoint(x: retentionPoints[0].0, y: retentionPoints[0].1))
            for i in 1..<retentionPoints.count {
                shaded.addLine(to: CGPoint(x: retentionPoints[i].0, y: retentionPoints[i].1))
            }
            // Close via forgetting curve
            shaded.addLine(to: CGPoint(x: 275, y: h - 30))
            shaded.addCurve(
                to: CGPoint(x: 40, y: 25),
                control1: CGPoint(x: 170, y: h - 48),
                control2: CGPoint(x: 80, y: 75)
            )
            shaded.closeSubpath()
            context.fill(shaded, with: .color(Color.lbG100.opacity(0.45)))

            // Retention curve (solid, with review bumps)
            var retention = Path()
            retention.move(to: CGPoint(x: 40, y: 25))
            for i in 1..<retentionPoints.count {
                retention.addLine(to: CGPoint(x: retentionPoints[i].0, y: retentionPoints[i].1))
            }
            context.stroke(retention,
                           with: .color(Color.lbBlack),
                           style: StrokeStyle(lineWidth: 2.5))

            // Review dots
            let dotPositions: [CGPoint] = [
                CGPoint(x: 67, y: 26),
                CGPoint(x: 104, y: 26),
                CGPoint(x: 147, y: 26),
                CGPoint(x: 201, y: 26),
                CGPoint(x: 257, y: 26),
            ]
            for dot in dotPositions {
                let dotRect = CGRect(x: dot.x - 4.5, y: dot.y - 4.5, width: 9, height: 9)
                context.fill(Circle().path(in: dotRect), with: .color(Color.lbBlack))
            }

            // "review" label
            context.draw(
                Text("review").font(.system(size: 8, weight: .semibold)).foregroundColor(Color.lbG500),
                at: CGPoint(x: 63, y: 16),
                anchor: .center
            )
        }
    }
}

// MARK: - C5: Talk It Out

private struct CarouselC5Talk: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: LBTheme.Spacing.sm) {
                Text("Talk it out.")
                    .font(LBTheme.serifFont(size: 28))
                    .foregroundStyle(Color.lbBlack)
                    .multilineTextAlignment(.center)

                Text("Practice conversation with an AI partner who adapts to your level.")
                    .font(LBTheme.Typography.body)
                    .foregroundStyle(Color.lbG500)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.top, LBTheme.Spacing.xxl)

            Spacer()

            // Chat card
            VStack(alignment: .leading, spacing: 14) {
                // Topic pill
                Text("Weekend Plans")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lbG500)
                    .tracking(0.3)
                    .padding(.horizontal, LBTheme.Spacing.md)
                    .padding(.vertical, LBTheme.Spacing.xs)
                    .background(Color.lbG50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Chat bubbles
                VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
                    // Mia label
                    Text("Mia")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.lbG400)

                    // AI bubble
                    HStack {
                        Text("\u{00BF}Qu\u{00E9} hiciste el fin de semana?")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.lbNearBlack)
                            .lineSpacing(3)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.lbG50)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 14,
                                    bottomLeadingRadius: 4,
                                    bottomTrailingRadius: 14,
                                    topTrailingRadius: 14
                                )
                            )
                        Spacer(minLength: 40)
                    }

                    // User bubble
                    HStack {
                        Spacer(minLength: 40)
                        Text("Fui al mercado con mi familia.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.lbWhite)
                            .lineSpacing(3)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.lbBlack)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 14,
                                    bottomLeadingRadius: 14,
                                    bottomTrailingRadius: 4,
                                    topTrailingRadius: 14
                                )
                            )
                    }

                    // AI bubble with highlighted word
                    HStack {
                        c5HighlightedBubble
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.lbG50)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 14,
                                    bottomLeadingRadius: 4,
                                    bottomTrailingRadius: 14,
                                    topTrailingRadius: 14
                                )
                            )
                        Spacer(minLength: 40)
                    }
                }
            }
            .padding(LBTheme.Spacing.lg)
            .frame(maxWidth: 310)
            .background(Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                    .strokeBorder(Color.lbG100, lineWidth: 1.5)
            }

            // Voice waveform
            HStack(spacing: 10) {
                // Bars
                HStack(alignment: .center, spacing: 3) {
                    ForEach(Array([8, 14, 20, 12, 6].enumerated()), id: \.offset) { _, height in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.lbBlack)
                            .frame(width: 3, height: CGFloat(height))
                    }
                }
                .frame(height: 20)

                Text("Voice or text \u{2014} your choice")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lbG400)
            }
            .padding(.top, 20)

            Spacer()
        }
        .padding(.horizontal, 30)
    }

    private var c5HighlightedBubble: Text {
        let a: Text = Text("\u{00A1}Qu\u{00E9} bien! \u{00BF}Qu\u{00E9} ")
            .font(.system(size: 14))
            .foregroundColor(Color.lbNearBlack)
        let b: Text = Text(highlightedWord("compraste"))
            .font(.system(size: 14))
            .foregroundColor(Color.lbNearBlack)
        let c: Text = Text("?")
            .font(.system(size: 14))
            .foregroundColor(Color.lbNearBlack)
        return a + b + c
    }
}

// MARK: - Helpers

private func highlightedWord(_ word: String) -> AttributedString {
    var attr = AttributedString(word)
    attr.backgroundColor = Color.lbHighlight
    return attr
}

#Preview {
    CarouselView(onComplete: {}, onSkip: {})
}
