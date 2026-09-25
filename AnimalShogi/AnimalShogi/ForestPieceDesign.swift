import SwiftUI

struct AnimalArtwork: View {
    let type: PieceType
    var body: some View { Image(assetName).resizable().scaledToFit().accessibilityHidden(true) }
    private var assetName: String {
        switch type { case .lion: "Dinosaur"; case .giraffe: "Crab"; case .elephant: "Snake"; case .chick: "Minnow"; case .hen: "Fish" }
    }
}

struct AnimalPieceCard: View {
    let piece: Piece
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7).fill(cardColor)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(red: 0.15, green: 0.12, blue: 0.12), lineWidth: 1.8))
                .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
            GeometryReader { proxy in
                AnimalArtwork(type: piece.type)
                    .frame(width: proxy.size.width * artworkScale.width,
                           height: proxy.size.height * artworkScale.height)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            // Movement markers stay above wide artwork such as the fish.
            MovementDots(type: piece.type).padding(5)
        }
        .rotationEffect(piece.owner == .cpu ? .degrees(180) : .zero)
        .aspectRatio(1, contentMode: .fit)
    }
    private var cardColor: Color {
        switch piece.type {
        case .lion: Color(red: 0.96, green: 0.61, blue: 0.60)
        case .giraffe, .elephant: Color(red: 0.82, green: 0.67, blue: 0.82)
        case .chick: Color(red: 0.91, green: 0.94, blue: 0.56)
        case .hen: Color(red: 1.00, green: 0.92, blue: 0.63)
        }
    }

    // Reference-card measurements: king 72%, orthogonal 74×62%,
    // diagonal 70×60%, chick 50×42% of the card.
    private var artworkScale: CGSize {
        switch piece.type {
        case .lion: CGSize(width: 0.72, height: 0.72)
        case .giraffe: CGSize(width: 0.74, height: 0.62)
        case .elephant: CGSize(width: 0.80, height: 0.70)
        // The source fish drawings have different transparent margins. These
        // values make their visible silhouettes occupy the same card width.
        case .chick: CGSize(width: 1.40, height: 1.00)
        case .hen: CGSize(width: 1.10, height: 1.00)
        }
    }
}

private struct MovementDots: View {
    let type: PieceType
    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(directions.enumerated()), id: \.offset) { _, direction in
                Circle().fill(dotColor)
                    .overlay(Circle().stroke(type == .hen ? Color.white : Color(red: 0.30, green: 0.18, blue: 0.18), lineWidth: type == .hen ? 1.5 : 1))
                    .shadow(color: .black.opacity(type == .hen ? 0.28 : 0), radius: 1)
                    .frame(width: type == .hen ? 8 : 6.5, height: type == .hen ? 8 : 6.5)
                    .position(x: proxy.size.width * coordinate(direction.0), y: proxy.size.height * coordinate(direction.1))
            }
        }
    }
    private var directions: [(Int, Int)] {
        switch type {
        case .lion: [(-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1),(1,1)]
        case .giraffe: [(0,-1),(-1,0),(1,0),(0,1)]
        case .elephant: [(-1,-1),(1,-1),(-1,1),(1,1)]
        case .chick: [(0,-1)]
        case .hen: [(-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(0,1)]
        }
    }
    private var dotColor: Color {
        type == .hen ? Color(red: 0.07, green: 0.36, blue: 0.72) : Color(red: 0.94, green: 0.31, blue: 0.20)
    }
    private func coordinate(_ value: Int) -> CGFloat { value == -1 ? 0.08 : (value == 1 ? 0.92 : 0.5) }
}
