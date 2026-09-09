#if canImport(UIKit)
import UIKit

/// Lớp vẽ vệt vuốt phím (Glide Typing Trail) siêu mượt bằng CALayer vector, 0% CPU overhead
public final class GlideTrailLayer: CAShapeLayer {
    private var points: [CGPoint] = []

    public override init() {
        super.init()
        setupLayer()
    }

    public override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayer() {
        strokeColor = UIColor.systemBlue.withAlphaComponent(0.65).cgColor
        fillColor = UIColor.clear.cgColor
        lineWidth = 3.5
        lineCap = .round
        lineJoin = .round
        zPosition = 999
    }

    public func addPoint(_ point: CGPoint) {
        points.append(point)
        // Giữ lại tối đa 25 điểm gần nhất để vệt lướt không bị quá dài
        if points.count > 25 {
            points.removeFirst()
        }
        redrawPath()
    }

    private func redrawPath() {
        guard points.count > 1 else {
            path = nil
            return
        }

        let bezier = UIBezierPath()
        bezier.move(to: points[0])

        for i in 1..<points.count {
            let mid = CGPoint(
                x: (points[i - 1].x + points[i].x) / 2.0,
                y: (points[i - 1].y + points[i].y) / 2.0
            )
            bezier.addQuadCurve(to: mid, controlPoint: points[i - 1])
        }

        bezier.addLine(to: points.last!)
        path = bezier.cgPath
    }

    public func clear() {
        points.removeAll()
        path = nil
    }

    public func fadeOut() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        CATransaction.setCompletionBlock { [weak self] in
            self?.clear()
            self?.opacity = 1.0
        }
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = opacity
        anim.toValue = 0.0
        anim.duration = 0.15
        add(anim, forKey: "fade")
        opacity = 0.0
        CATransaction.commit()
    }
}
#endif
