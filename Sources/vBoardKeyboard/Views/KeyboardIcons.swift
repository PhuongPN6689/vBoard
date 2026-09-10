#if canImport(UIKit)
import UIKit

/// Bộ sinh biểu tượng Vector (UIBezierPath / SVG-equivalent) sắc nét 100% cho vBoard
@MainActor
public enum KeyboardIcons {

    /// Biểu tượng xóa lùi Backspace hình ngũ giác kèm dấu X bên trong
    public static func deleteIcon(size: CGSize = CGSize(width: 22, height: 17)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let path = UIBezierPath()
            let w = size.width
            let h = size.height
            let arrowTipX: CGFloat = 1.0
            let shoulderX: CGFloat = w * 0.32
            let topY: CGFloat = 1.0
            let botY: CGFloat = h - 1.0
            let rightX: CGFloat = w - 1.0
            let cornerRadius: CGFloat = 2.5

            path.move(to: CGPoint(x: shoulderX, y: topY))
            path.addLine(to: CGPoint(x: rightX - cornerRadius, y: topY))
            path.addQuadCurve(to: CGPoint(x: rightX, y: topY + cornerRadius), controlPoint: CGPoint(x: rightX, y: topY))
            path.addLine(to: CGPoint(x: rightX, y: botY - cornerRadius))
            path.addQuadCurve(to: CGPoint(x: rightX - cornerRadius, y: botY), controlPoint: CGPoint(x: rightX, y: botY))
            path.addLine(to: CGPoint(x: shoulderX, y: botY))
            path.addLine(to: CGPoint(x: arrowTipX, y: h / 2.0))
            path.close()

            path.lineWidth = 1.4
            path.lineJoinStyle = .round
            UIColor.black.setStroke()
            path.stroke()

            // Dấu X bên trong
            let crossPath = UIBezierPath()
            let cx = shoulderX + (rightX - shoulderX) / 2.0
            let cy = h / 2.0
            let arm: CGFloat = 3.2

            crossPath.move(to: CGPoint(x: cx - arm, y: cy - arm))
            crossPath.addLine(to: CGPoint(x: cx + arm, y: cy + arm))
            crossPath.move(to: CGPoint(x: cx + arm, y: cy - arm))
            crossPath.addLine(to: CGPoint(x: cx - arm, y: cy + arm))
            crossPath.lineWidth = 1.4
            crossPath.lineCapStyle = .round
            crossPath.stroke()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }

    /// Biểu tượng phím Shift (mũi tên rỗng, đặc, hoặc CapsLock)
    public static func shiftIcon(isCapsLocked: Bool, isShiftActive: Bool, size: CGSize = CGSize(width: 19, height: 19)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let w = size.width
            let h = size.height
            let path = UIBezierPath()

            let tip = CGPoint(x: w / 2.0, y: 1.5)
            let leftArrow = CGPoint(x: 1.5, y: h * 0.48)
            let rightArrow = CGPoint(x: w - 1.5, y: h * 0.48)
            let leftInner = CGPoint(x: w * 0.32, y: h * 0.48)
            let rightInner = CGPoint(x: w * 0.68, y: h * 0.48)
            let stemBotY = isCapsLocked ? (h * 0.72) : (h - 1.5)

            path.move(to: tip)
            path.addLine(to: rightArrow)
            path.addLine(to: rightInner)
            path.addLine(to: CGPoint(x: rightInner.x, y: stemBotY))
            path.addLine(to: CGPoint(x: leftInner.x, y: stemBotY))
            path.addLine(to: CGPoint(x: leftInner.x, y: leftArrow.y))
            path.addLine(to: leftArrow)
            path.close()

            path.lineJoinStyle = .round
            path.lineWidth = 1.5

            if isCapsLocked || isShiftActive {
                UIColor.black.setFill()
                path.fill()
            } else {
                UIColor.black.setStroke()
                path.stroke()
            }

            if isCapsLocked {
                let bar = UIBezierPath(roundedRect: CGRect(x: leftInner.x - 1, y: h - 3.5, width: (rightInner.x - leftInner.x) + 2, height: 2.0), cornerRadius: 1.0)
                UIColor.black.setFill()
                bar.fill()
            }
        }
        return img.withRenderingMode(.alwaysTemplate)
    }

    /// Biểu tượng phím Return / Enter vector
    public static func returnIcon(type: UIReturnKeyType, size: CGSize = CGSize(width: 19, height: 19)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let w = size.width
            let h = size.height
            let path = UIBezierPath()

            switch type {
            case .search:
                // Kính lúp
                let radius: CGFloat = 5.2
                let center = CGPoint(x: 7.5, y: 7.5)
                let circle = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                circle.lineWidth = 1.6
                UIColor.black.setStroke()
                circle.stroke()

                let handle = UIBezierPath()
                handle.move(to: CGPoint(x: center.x + radius * 0.7, y: center.y + radius * 0.7))
                handle.addLine(to: CGPoint(x: w - 2.0, y: h - 2.0))
                handle.lineWidth = 2.0
                handle.lineCapStyle = .round
                handle.stroke()

            case .send:
                // Máy bay giấy
                path.move(to: CGPoint(x: 2.0, y: 2.0))
                path.addLine(to: CGPoint(x: w - 2.0, y: h / 2.0))
                path.addLine(to: CGPoint(x: 2.0, y: h - 2.0))
                path.addLine(to: CGPoint(x: 6.0, y: h / 2.0))
                path.close()
                UIColor.black.setFill()
                path.fill()

            case .go, .next:
                // Mũi tên phải
                path.move(to: CGPoint(x: 3.0, y: h / 2.0))
                path.addLine(to: CGPoint(x: w - 4.0, y: h / 2.0))
                path.move(to: CGPoint(x: w - 9.0, y: 4.0))
                path.addLine(to: CGPoint(x: w - 3.5, y: h / 2.0))
                path.addLine(to: CGPoint(x: w - 9.0, y: h - 4.0))
                path.lineWidth = 1.8
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                UIColor.black.setStroke()
                path.stroke()

            default:
                // Mũi tên Enter cong chuẩn ↵
                path.move(to: CGPoint(x: w - 3.5, y: 3.5))
                path.addLine(to: CGPoint(x: w - 3.5, y: h * 0.65))
                path.addLine(to: CGPoint(x: 4.5, y: h * 0.65))
                path.move(to: CGPoint(x: 9.0, y: h * 0.65 - 4.5))
                path.addLine(to: CGPoint(x: 4.0, y: h * 0.65))
                path.addLine(to: CGPoint(x: 9.0, y: h * 0.65 + 4.5))
                path.lineWidth = 1.8
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                UIColor.black.setStroke()
                path.stroke()
            }
        }
        return img.withRenderingMode(.alwaysTemplate)
    }

    /// Biểu tượng Nút Dán (Paste Button) trên thanh công cụ
    public static func pasteIcon(size: CGSize = CGSize(width: 18, height: 18)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let w = size.width
            let h = size.height

            // Khung bìa kẹp tài liệu
            let boardRect = CGRect(x: 2.0, y: 3.0, width: w - 4.0, height: h - 4.0)
            let boardPath = UIBezierPath(roundedRect: boardRect, cornerRadius: 2.5)
            boardPath.lineWidth = 1.3
            UIColor.black.setStroke()
            boardPath.stroke()

            // Đầu kẹp trên (clip)
            let clipW: CGFloat = 7.0
            let clipRect = CGRect(x: (w - clipW) / 2.0, y: 1.0, width: clipW, height: 3.5)
            let clipPath = UIBezierPath(roundedRect: clipRect, cornerRadius: 1.2)
            UIColor.black.setFill()
            clipPath.fill()

            // Các vạch văn bản bên trong
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: 5.0, y: 8.5))
            linePath.addLine(to: CGPoint(x: w - 5.0, y: 8.5))
            linePath.move(to: CGPoint(x: 5.0, y: 11.5))
            linePath.addLine(to: CGPoint(x: w - 7.0, y: 11.5))
            linePath.lineWidth = 1.2
            linePath.lineCapStyle = .round
            UIColor.black.setStroke()
            linePath.stroke()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }

    /// Biểu tượng Lịch sử sao chép (Clipboard History - 2 trang xếp chồng kèm đồng hồ nhỏ hoặc kẹp)
    public static func clipboardHistoryIcon(size: CGSize = CGSize(width: 18, height: 18)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let w = size.width
            let h = size.height

            // Trang sau (offset nhẹ)
            let backRect = CGRect(x: 4.5, y: 1.5, width: w - 6.0, height: h - 5.5)
            let backPath = UIBezierPath(roundedRect: backRect, cornerRadius: 2.0)
            backPath.lineWidth = 1.1
            UIColor.black.setStroke()
            backPath.stroke()

            // Trang trước
            let frontRect = CGRect(x: 1.5, y: 4.5, width: w - 6.0, height: h - 5.5)
            let frontPath = UIBezierPath(roundedRect: frontRect, cornerRadius: 2.0)
            frontPath.lineWidth = 1.3
            UIColor.black.setStroke()
            frontPath.stroke()

            // Các vạch dòng kẻ trên trang trước
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: 4.0, y: 8.5))
            linePath.addLine(to: CGPoint(x: w - 7.5, y: 8.5))
            linePath.move(to: CGPoint(x: 4.0, y: 11.5))
            linePath.addLine(to: CGPoint(x: w - 9.5, y: 11.5))
            linePath.lineWidth = 1.1
            linePath.lineCapStyle = .round
            UIColor.black.setStroke()
            linePath.stroke()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }

    /// Biểu tượng hạ bàn phím
    public static func dismissIcon(size: CGSize = CGSize(width: 18, height: 14)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 2.0, y: 4.0))
            path.addLine(to: CGPoint(x: size.width / 2.0, y: size.height - 3.0))
            path.addLine(to: CGPoint(x: size.width - 2.0, y: 4.0))
            path.lineWidth = 2.0
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.black.setStroke()
            path.stroke()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }

    /// Biểu tượng đổi bên một tay (Mũi tên 2 chiều trái - phải)
    public static func oneHandedSwapIcon(size: CGSize = CGSize(width: 20, height: 16)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let w = size.width
            let h = size.height
            let path = UIBezierPath()

            // Trục ngang
            path.move(to: CGPoint(x: 2.5, y: h / 2.0))
            path.addLine(to: CGPoint(x: w - 2.5, y: h / 2.0))

            // Đầu mũi tên trái
            path.move(to: CGPoint(x: 6.5, y: h / 2.0 - 4.0))
            path.addLine(to: CGPoint(x: 2.5, y: h / 2.0))
            path.addLine(to: CGPoint(x: 6.5, y: h / 2.0 + 4.0))

            // Đầu mũi tên phải
            path.move(to: CGPoint(x: w - 6.5, y: h / 2.0 - 4.0))
            path.addLine(to: CGPoint(x: w - 2.5, y: h / 2.0))
            path.addLine(to: CGPoint(x: w - 6.5, y: h / 2.0 + 4.0))

            path.lineWidth = 1.8
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.black.setStroke()
            path.stroke()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }

    /// Biểu tượng phóng to toàn màn hình (Mũi tên 2 đầu chéo ra ngoài)
    public static func oneHandedExpandIcon(size: CGSize = CGSize(width: 18, height: 18)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let w = size.width
            let h = size.height
            let path = UIBezierPath()

            // Mũi tên góc trên trái
            path.move(to: CGPoint(x: 2.0, y: 7.0))
            path.addLine(to: CGPoint(x: 2.0, y: 2.0))
            path.addLine(to: CGPoint(x: 7.0, y: 2.0))

            // Mũi tên góc dưới phải
            path.move(to: CGPoint(x: w - 7.0, y: h - 2.0))
            path.addLine(to: CGPoint(x: w - 2.0, y: h - 2.0))
            path.addLine(to: CGPoint(x: w - 2.0, y: h - 7.0))

            // Đường chéo nối
            path.move(to: CGPoint(x: 2.5, y: 2.5))
            path.addLine(to: CGPoint(x: w - 2.5, y: h - 2.5))

            path.lineWidth = 1.8
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.black.setStroke()
            path.stroke()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }

    /// Biểu tượng cài đặt bánh răng (Gear Vector)
    public static func settingsGearIcon(size: CGSize = CGSize(width: 20, height: 20)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let cx = size.width / 2.0
            let cy = size.height / 2.0
            let outerR = min(cx, cy) - 2.0
            let innerR = outerR * 0.72
            let holeR = outerR * 0.38
            let teeth = 6

            let gearPath = UIBezierPath()
            for i in 0..<teeth {
                let angle = Double(i) * (2.0 * .pi / Double(teeth))
                let toothWidth = .pi / Double(teeth) * 0.45

                let a1 = angle - toothWidth
                let a2 = angle + toothWidth
                let a3 = angle + (2.0 * .pi / Double(teeth)) - toothWidth

                let p1 = CGPoint(x: cx + CGFloat(cos(a1)) * innerR, y: cy + CGFloat(sin(a1)) * innerR)
                let p2 = CGPoint(x: cx + CGFloat(cos(a1)) * outerR, y: cy + CGFloat(sin(a1)) * outerR)
                let p3 = CGPoint(x: cx + CGFloat(cos(a2)) * outerR, y: cy + CGFloat(sin(a2)) * outerR)
                let p4 = CGPoint(x: cx + CGFloat(cos(a2)) * innerR, y: cy + CGFloat(sin(a2)) * innerR)
                let p5 = CGPoint(x: cx + CGFloat(cos(a3)) * innerR, y: cy + CGFloat(sin(a3)) * innerR)

                if i == 0 {
                    gearPath.move(to: p1)
                } else {
                    gearPath.addLine(to: p1)
                }
                gearPath.addLine(to: p2)
                gearPath.addLine(to: p3)
                gearPath.addLine(to: p4)
                gearPath.addLine(to: p5)
            }
            gearPath.close()

            // Lỗ tròn tâm bánh răng
            let holePath = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy), radius: holeR, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            gearPath.append(holePath)
            gearPath.usesEvenOddFillRule = true

            UIColor.black.setFill()
            gearPath.fill()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }

    /// Biểu tượng mặt cười Emoji (Smile Vector)
    public static func emojiSmileIcon(size: CGSize = CGSize(width: 20, height: 20)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let cx = size.width / 2.0
            let cy = size.height / 2.0
            let r = min(cx, cy) - 2.0

            // Đường tròn mặt
            let faceCircle = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy), radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            faceCircle.lineWidth = 1.6
            UIColor.black.setStroke()
            faceCircle.stroke()

            // 2 mắt
            let eyeOffsetX: CGFloat = r * 0.35
            let eyeOffsetY: CGFloat = r * 0.25
            let eyeR: CGFloat = 1.4

            let leftEye = UIBezierPath(arcCenter: CGPoint(x: cx - eyeOffsetX, y: cy - eyeOffsetY), radius: eyeR, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            let rightEye = UIBezierPath(arcCenter: CGPoint(x: cx + eyeOffsetX, y: cy - eyeOffsetY), radius: eyeR, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor.black.setFill()
            leftEye.fill()
            rightEye.fill()

            // Miệng cười
            let smilePath = UIBezierPath()
            let smileY = cy + r * 0.1
            let smileW = r * 0.52
            smilePath.move(to: CGPoint(x: cx - smileW, y: smileY))
            smilePath.addQuadCurve(to: CGPoint(x: cx + smileW, y: smileY), controlPoint: CGPoint(x: cx, y: cy + r * 0.65))
            smilePath.lineWidth = 1.6
            smilePath.lineCapStyle = .round
            UIColor.black.setStroke()
            smilePath.stroke()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }
}
#endif
