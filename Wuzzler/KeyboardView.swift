import SwiftUI

struct KeyboardView: View {
    let onKeyTap: (String) -> Void
    let onDelete: () -> Void

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
                        Text(key)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(UIColor.systemGray4))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onKeyTap(key)
                            }
                            .accessibilityLabel(key)
                    }
                    if rowIndex == 2 {
                        Image(systemName: "delete.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(UIColor.systemGray4))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onDelete()
                            }
                            .accessibilityLabel("Delete")
                    }
                }
            }
        }
    }
}
