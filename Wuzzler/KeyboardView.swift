import SwiftUI

struct KeyboardView: View {
    let onKeyTap: (String) -> Void
    let onDelete: () -> Void
    var disabledKeys: Set<String> = []
    var blankedKeys: Set<String> = []
    var showsKeyPopups: Bool = true

    @State private var pressedKey: String?
    @State private var keyFrames: [KeyboardKeyFrame] = []

    private let rows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 4) {
                    if rowIndex == 2 {
                        Spacer(minLength: 0)
                    }
                    ForEach(row, id: \.self) { key in
                        letterKey(key)
                    }
                    if rowIndex == 2 {
                        deleteKey
                    }
                }
            }
        }
        .coordinateSpace(name: KeyboardCoordinateSpace.name)
        .contentShape(Rectangle())
        .onPreferenceChange(KeyboardKeyFramePreferenceKey.self) { frames in
            keyFrames = frames
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(KeyboardCoordinateSpace.name))
                .onChanged { value in
                    updatePressedKey(at: value.location)
                }
                .onEnded { value in
                    submitKey(at: value.location)
                }
        )
    }

    private func letterKey(_ key: String) -> some View {
        let isDisabled = disabledKeys.contains(key)
        let isBlanked = blankedKeys.contains(key)
        let isPressed = pressedKey == key && !isDisabled

        return Text(isBlanked ? "" : key)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(isDisabled ? .secondary.opacity(0.35) : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isDisabled ? Color(UIColor.systemGray5) : Color(UIColor.systemGray4))
            )
            .background(
                KeyboardKeyFrameReader(key: key, isDisabled: isDisabled, isBlanked: isBlanked)
            )
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if showsKeyPopups && isPressed && !isBlanked {
                    KeyPopup(letter: key)
                        .offset(y: -52)
                        .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
                        .zIndex(2)
                        .allowsHitTesting(false)
                }
            }
            .zIndex(isPressed ? 10 : 0)
            .opacity(isDisabled ? 0.65 : 1.0)
            .accessibilityLabel(isBlanked ? "\(key), unavailable" : key)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                guard !isDisabled else { return }
                onKeyTap(key)
            }
    }

    private var deleteKey: some View {
        Image(systemName: "delete.left")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.primary)
            .frame(width: 50, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(UIColor.systemGray4))
            )
            .background(
                KeyboardKeyFrameReader(key: KeyboardKeys.delete, isDisabled: false, isBlanked: false)
            )
            .contentShape(Rectangle())
            .accessibilityLabel("Delete")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                onDelete()
            }
    }

    private func updatePressedKey(at location: CGPoint) {
        let nextKey = keyFrame(at: location)?.key
        guard pressedKey != nextKey else { return }
        pressedKey = nextKey
        if nextKey != nil {
            Haptics.impact(.soft)
        }
    }

    private func submitKey(at location: CGPoint) {
        let releasedKey = keyFrame(at: location)?.key ?? pressedKey
        pressedKey = nil

        guard let releasedKey else { return }
        if releasedKey == KeyboardKeys.delete {
            onDelete()
        } else {
            onKeyTap(releasedKey)
        }
    }

    private func keyFrame(at location: CGPoint) -> KeyboardKeyFrame? {
        if let exactFrame = keyFrames.first(where: { frame in
            !frame.isDisabled && frame.frame.contains(location)
        }) {
            return exactFrame
        }

        return keyFrames
            .filter { frame in
                !frame.isDisabled && frame.frame.insetBy(dx: -3, dy: -5).contains(location)
            }
            .min { lhs, rhs in
                lhs.frame.center.distance(to: location) < rhs.frame.center.distance(to: location)
            }
    }
}

private enum KeyboardCoordinateSpace {
    static let name = "WuzzlerKeyboardCoordinateSpace"
}

private enum KeyboardKeys {
    static let delete = "DELETE"
}

private struct KeyboardKeyFrame: Equatable {
    let key: String
    let frame: CGRect
    let isDisabled: Bool
    let isBlanked: Bool
}

private struct KeyboardKeyFramePreferenceKey: PreferenceKey {
    static let defaultValue: [KeyboardKeyFrame] = []

    static func reduce(value: inout [KeyboardKeyFrame], nextValue: () -> [KeyboardKeyFrame]) {
        value.append(contentsOf: nextValue())
    }
}

private struct KeyboardKeyFrameReader: View {
    let key: String
    let isDisabled: Bool
    let isBlanked: Bool

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: KeyboardKeyFramePreferenceKey.self,
                value: [
                    KeyboardKeyFrame(
                        key: key,
                        frame: proxy.frame(in: .named(KeyboardCoordinateSpace.name)),
                        isDisabled: isDisabled,
                        isBlanked: isBlanked
                    )
                ]
            )
        }
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

private struct KeyPopup: View {
    let letter: String

    var body: some View {
        Text(letter)
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)
            .frame(width: 42, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
            )
            .overlay(alignment: .bottom) {
                TrianglePointer()
                    .fill(Color(UIColor.systemBackground))
                    .frame(width: 14, height: 8)
                    .offset(y: 7)
            }
    }
}

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
