#if DEBUG
import UIKit

/// Captures a "before" snapshot of a target view and lets you compare it with
/// an "after" state using a draggable split-screen divider.
internal final class SnapshotCompareVC: UIViewController {

    private let targetView: UIView
    private var beforeImage: UIImage
    private var afterImage: UIImage?

    // MARK: - UI

    private let beforeImageView = UIImageView()
    private let afterImageView  = UIImageView()
    private let dividerView     = UIView()
    private let handleView      = UIView()
    private let beforeLabel     = UILabel()
    private let afterLabel      = UILabel()
    private let captureButton   = UIButton(type: .system)
    private let hintLabel       = UILabel()

    private var dividerCenterConstraint: NSLayoutConstraint?

    // MARK: - Init

    internal init(targetView: UIView) {
        self.targetView = targetView
        self.beforeImage = targetView.snapshot() ?? UIImage()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Snapshot Compare"
        setupAppearance()
        setupUI()
        setupGestures()
    }

    private func setupAppearance() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = PhantomTheme.shared.backgroundColor
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
        navigationController?.navigationBar.tintColor = UIColor.Phantom.neonAzure
    }

    private func setupUI() {
        // Before image (full width background layer)
        beforeImageView.image = beforeImage
        beforeImageView.contentMode = .scaleAspectFit
        beforeImageView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        beforeImageView.translatesAutoresizingMaskIntoConstraints = false

        // After image (clips to divider width)
        afterImageView.image = beforeImage  // starts as copy
        afterImageView.contentMode = .scaleAspectFit
        afterImageView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        afterImageView.clipsToBounds = true
        afterImageView.translatesAutoresizingMaskIntoConstraints = false

        // Divider line
        dividerView.backgroundColor = UIColor.Phantom.neonAzure
        dividerView.translatesAutoresizingMaskIntoConstraints = false

        // Handle knob
        handleView.backgroundColor = UIColor.Phantom.neonAzure
        handleView.layer.cornerRadius = 16
        handleView.translatesAutoresizingMaskIntoConstraints = false

        // Arrow indicators
        let arrowLeft = makeArrowLabel("◀")
        let arrowRight = makeArrowLabel("▶")
        handleView.addSubview(arrowLeft)
        handleView.addSubview(arrowRight)
        arrowLeft.translatesAutoresizingMaskIntoConstraints = false
        arrowRight.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arrowLeft.centerYAnchor.constraint(equalTo: handleView.centerYAnchor),
            arrowLeft.leadingAnchor.constraint(equalTo: handleView.leadingAnchor, constant: 4),
            arrowRight.centerYAnchor.constraint(equalTo: handleView.centerYAnchor),
            arrowRight.trailingAnchor.constraint(equalTo: handleView.trailingAnchor, constant: -4),
        ])

        // Labels
        beforeLabel.text = " BEFORE "
        beforeLabel.font = .systemFont(ofSize: 9, weight: .black)
        beforeLabel.textColor = UIColor.Phantom.vibrantOrange
        beforeLabel.backgroundColor = UIColor.Phantom.vibrantOrange.withAlphaComponent(0.2)
        beforeLabel.layer.cornerRadius = 6
        beforeLabel.layer.masksToBounds = true
        beforeLabel.translatesAutoresizingMaskIntoConstraints = false

        afterLabel.text = " AFTER "
        afterLabel.font = .systemFont(ofSize: 9, weight: .black)
        afterLabel.textColor = UIColor.Phantom.vibrantGreen
        afterLabel.backgroundColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.2)
        afterLabel.layer.cornerRadius = 6
        afterLabel.layer.masksToBounds = true
        afterLabel.translatesAutoresizingMaskIntoConstraints = false

        // Capture button
        if #available(iOS 13.0, *) {
            captureButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        }
        captureButton.setTitle("  Capture After", for: .normal)
        captureButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        captureButton.tintColor = UIColor.Phantom.vibrantGreen
        captureButton.backgroundColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.12)
        captureButton.layer.cornerRadius = 14
        captureButton.layer.borderWidth = 1
        captureButton.layer.borderColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.4).cgColor
        captureButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureAfter), for: .touchUpInside)

        // Hint
        hintLabel.text = "Navigate back, make changes, return and tap \"Capture After\"\nThen drag the divider to compare"
        hintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 2
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        // Layout
        [beforeImageView, afterImageView, dividerView, handleView,
         beforeLabel, afterLabel, captureButton, hintLabel].forEach { view.addSubview($0) }

        let comparisonBottom = view.centerYAnchor
        let divCenter = dividerView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        dividerCenterConstraint = divCenter

        NSLayoutConstraint.activate([
            beforeImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            beforeImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            beforeImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            beforeImageView.bottomAnchor.constraint(equalTo: comparisonBottom),

            afterImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            afterImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            afterImageView.trailingAnchor.constraint(equalTo: dividerView.leadingAnchor),
            afterImageView.bottomAnchor.constraint(equalTo: comparisonBottom),

            dividerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            dividerView.widthAnchor.constraint(equalToConstant: 2),
            dividerView.bottomAnchor.constraint(equalTo: comparisonBottom),
            divCenter,

            handleView.centerXAnchor.constraint(equalTo: dividerView.centerXAnchor),
            handleView.centerYAnchor.constraint(equalTo: dividerView.centerYAnchor),
            handleView.widthAnchor.constraint(equalToConstant: 44),
            handleView.heightAnchor.constraint(equalToConstant: 32),

            beforeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            beforeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            afterLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            afterLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            hintLabel.topAnchor.constraint(equalTo: comparisonBottom, constant: 24),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            captureButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 20),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func makeArrowLabel(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = .systemFont(ofSize: 8, weight: .bold)
        lbl.textColor = .white
        return lbl
    }

    // MARK: - Gestures

    private func setupGestures() {
        let panDivider = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        dividerView.isUserInteractionEnabled = true
        dividerView.addGestureRecognizer(panDivider)

        let panHandle = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        handleView.addGestureRecognizer(panHandle)
    }

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        let dx = gr.translation(in: view).x
        let current = dividerCenterConstraint?.constant ?? 0
        let halfWidth = view.bounds.width / 2 - 8
        dividerCenterConstraint?.constant = max(-halfWidth, min(halfWidth, current + dx))
        gr.setTranslation(.zero, in: view)
        view.layoutIfNeeded()
    }

    // MARK: - Actions

    @objc private func captureAfter() {
        let snap = targetView.snapshot() ?? UIImage()
        afterImage = snap
        afterImageView.image = snap

        captureButton.setTitle("  Refresh After", for: .normal)
        hintLabel.text = "Drag the divider ← → to compare before & after"

        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }
}
#endif
