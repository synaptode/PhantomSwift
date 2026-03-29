#if DEBUG
import UIKit

/// Displays the app's security posture.
internal final class SecurityDashboardVC: UIViewController {
    private var report: PhantomSecurityInspector.SecurityReport = PhantomSecurityInspector.shared.generateReport()
    
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let headerView = UIView()
    private let progressRing = CircularProgressView()
    private let statusLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        animateIn()
    }
    
    private func setupUI() {
        title = "Vault Integrity"
        view.backgroundColor = .black

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "🔑 Keychain",
            style: .plain,
            target: self,
            action: #selector(openKeychain)
        )

        setupBackgroundAesthetics()
        setupHeader()
        setupStackView()

        for check in report.checks {
            let color: UIColor = check.isPassed
                ? UIColor.Phantom.success
                : (check.deduction >= 30 ? UIColor.Phantom.error : UIColor.Phantom.warning)
            addSecurityCard(
                title: check.title,
                status: check.status,
                deduction: check.deduction,
                color: color,
                description: check.detail
            )
        }
    }

    @objc private func openKeychain() {
        navigationController?.pushViewController(SecurityKeychainVC(), animated: true)
    }
    
    private func setupBackgroundAesthetics() {
        let gridLayer = CALayer()
        gridLayer.frame = view.bounds
        gridLayer.backgroundColor = UIColor.black.cgColor
        view.layer.insertSublayer(gridLayer, at: 0)
        
        // Subtle scanline effect
        let scanline = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 2))
        scanline.backgroundColor = UIColor.Phantom.primaryColor.withAlphaComponent(0.05)
        view.addSubview(scanline)
        
        UIView.animate(withDuration: 4.0, delay: 0, options: [.repeat, .curveLinear], animations: {
            scanline.frame.origin.y = self.view.bounds.height
        }, completion: nil)
    }
    
    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        progressRing.translatesAutoresizingMaskIntoConstraints = false
        progressRing.progress = CGFloat(report.score) / 100.0
        progressRing.tintColor = report.score == 100 ? UIColor.Phantom.success : (report.score >= 70 ? UIColor.Phantom.warning : UIColor.Phantom.error)
        headerView.addSubview(progressRing)
        
        statusLabel.text = report.statusPhrase.uppercased()
        statusLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .black)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(statusLabel)
        
        let scoreLabel = UILabel()
        scoreLabel.text = "\(report.score)%"
        scoreLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        scoreLabel.textColor = .white
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(scoreLabel)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 240),
            
            progressRing.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            progressRing.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            progressRing.widthAnchor.constraint(equalToConstant: 140),
            progressRing.heightAnchor.constraint(equalToConstant: 140),
            
            scoreLabel.centerXAnchor.constraint(equalTo: progressRing.centerXAnchor),
            scoreLabel.centerYAnchor.constraint(equalTo: progressRing.centerYAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: progressRing.bottomAnchor, constant: 20),
            statusLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor)
        ])
    }
    
    private func setupStackView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 0),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }
    
    private func addSecurityCard(title: String, status: String, deduction: Int, color: UIColor, description: String) {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.1, alpha: 0.8)
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = (deduction > 0 ? color : UIColor.white).withAlphaComponent(0.1).cgColor
        
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .black)
        titleLabel.textColor = .white.withAlphaComponent(0.5)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        let statusLabel = UILabel()
        statusLabel.text = status
        statusLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        statusLabel.textColor = color
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statusLabel)
        
        // Deduction Indicator (The "Why")
        if deduction > 0 {
            let deductionBadge = UILabel()
            deductionBadge.text = "-\(deduction) PTS"
            deductionBadge.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .black)
            deductionBadge.textColor = .black
            deductionBadge.backgroundColor = color
            deductionBadge.textAlignment = .center
            deductionBadge.layer.cornerRadius = 4
            deductionBadge.layer.masksToBounds = true
            deductionBadge.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(deductionBadge)
            
            NSLayoutConstraint.activate([
                deductionBadge.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
                deductionBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                deductionBadge.heightAnchor.constraint(equalToConstant: 18),
                deductionBadge.widthAnchor.constraint(equalToConstant: 50)
            ])
        }
        
        let descLabel = UILabel()
        descLabel.text = description
        descLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        descLabel.textColor = .white.withAlphaComponent(0.4)
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(descLabel)
        
        stackView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 90),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            
            descLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            descLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            descLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
    }
    
    private func animateIn() {
        progressRing.animate()
        for (index, card) in stackView.arrangedSubviews.enumerated() {
            UIView.animate(withDuration: 0.5, delay: 0.2 + Double(index) * 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                card.alpha = 1
                card.transform = .identity
            }, completion: nil)
        }
    }
}

// MARK: - Helper Views
private final class CircularProgressView: UIView {
    private let shapeLayer = CAShapeLayer()
    private let trackLayer = CAShapeLayer()
    var progress: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.white.withAlphaComponent(0.1).cgColor
        trackLayer.lineWidth = 10
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)
        
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 10
        shapeLayer.lineCap = .round
        shapeLayer.strokeEnd = 0
        layer.addSublayer(shapeLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - 10) / 2
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: -CGFloat.pi / 2, endAngle: 1.5 * CGFloat.pi, clockwise: true)
        
        trackLayer.path = path.cgPath
        shapeLayer.path = path.cgPath
    }
    
    override var tintColor: UIColor! {
        didSet {
            shapeLayer.strokeColor = tintColor.cgColor
            shapeLayer.shadowColor = tintColor.cgColor
            shapeLayer.shadowRadius = 8
            shapeLayer.shadowOpacity = 0.5
            shapeLayer.shadowOffset = .zero
        }
    }
    
    func animate() {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = progress
        animation.duration = 1.0
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        shapeLayer.add(animation, forKey: "progress")
    }
}
#endif
