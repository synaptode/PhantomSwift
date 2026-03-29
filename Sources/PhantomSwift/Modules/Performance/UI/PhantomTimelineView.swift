#if DEBUG
import UIKit

/// A custom view that renders a smooth line chart for performance history.
internal final class PhantomTimelineView: UIView {
    private var dataPoints: [Double] = []
    private let lineLayer = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()
    
    var lineColor: UIColor = UIColor.Phantom.primary {
        didSet { lineLayer.strokeColor = lineColor.cgColor }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        backgroundColor = .clear
        
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 2
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        layer.addSublayer(lineLayer)
    }
    
    func update(with points: [Double]) {
        self.dataPoints = points
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        drawChart()
    }
    
    private func drawChart() {
        guard dataPoints.count > 1 else { return }
        
        let path = UIBezierPath()
        let fillPath = UIBezierPath()
        
        let width = bounds.width
        let height = bounds.height
        let step = width / CGFloat(dataPoints.count - 1)
        
        let maxValue = dataPoints.max() ?? 1.0
        let scale = maxValue > 0 ? height / CGFloat(maxValue) : 1.0
        
        var points: [CGPoint] = []
        for (index, point) in dataPoints.enumerated() {
            let x = CGFloat(index) * step
            let y = height - (CGFloat(point) * scale)
            points.append(CGPoint(x: x, y: y))
        }
        
        // Use Bezier Smoothing
        path.move(to: points[0])
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i+1]
            let controlPoint1 = CGPoint(x: p1.x + (p2.x - p1.x) / 2, y: p1.y)
            let controlPoint2 = CGPoint(x: p1.x + (p2.x - p1.x) / 2, y: p2.y)
            path.addCurve(to: p2, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
        }
        
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = lineColor.cgColor
        lineLayer.shadowColor = lineColor.cgColor
        lineLayer.shadowOpacity = 0.5
        lineLayer.shadowRadius = 4
        lineLayer.shadowOffset = .zero
        
        // Gradient Fill
        fillPath.append(path)
        fillPath.addLine(to: CGPoint(x: width, y: height))
        fillPath.addLine(to: CGPoint(x: 0, y: height))
        fillPath.close()
        
        if gradientLayer.superlayer == nil {
            gradientLayer.mask = CAShapeLayer()
            layer.insertSublayer(gradientLayer, at: 0)
        }
        
        let maskLayer = gradientLayer.mask as? CAShapeLayer
        maskLayer?.path = fillPath.cgPath
        gradientLayer.colors = [lineColor.withAlphaComponent(0.3).cgColor, lineColor.withAlphaComponent(0).cgColor]
        gradientLayer.frame = bounds
    }
}
#endif
