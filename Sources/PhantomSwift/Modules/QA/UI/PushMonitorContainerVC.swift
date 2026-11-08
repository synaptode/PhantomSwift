#if DEBUG
import UIKit

/// Container view controller hosting both the Live Push Notification Monitor and the Push Simulator.
internal final class PushMonitorContainerVC: UIViewController {

    private let segmentedControl = UISegmentedControl(items: ["Live Monitor", "Simulator"])
    private let containerView = UIView()

    private let monitorVC = PushMonitorVC()
    private let simulatorVC = PushSimulatorVC()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Push Notifications"
        view.backgroundColor = PhantomTheme.shared.backgroundColor

        setupNavigation()
        setupUI()
        displayChild(index: 0)
    }

    private func setupNavigation() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(didChangeSegment), for: .valueChanged)
        segmentedControl.applyPhantomStyle()
        navigationItem.titleView = segmentedControl

        let closeButton = UIBarButtonItem(
            image: UIImage.phantomSymbol("xmark"),
            style: .plain,
            target: self,
            action: #selector(didTapClose)
        )
        navigationItem.leftBarButtonItem = closeButton
    }

    private func setupUI() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func didChangeSegment() {
        displayChild(index: segmentedControl.selectedSegmentIndex)
    }

    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    private func displayChild(index: Int) {
        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        let childVC: UIViewController = (index == 0) ? monitorVC : simulatorVC
        addChild(childVC)
        childVC.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(childVC.view)

        NSLayoutConstraint.activate([
            childVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            childVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            childVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            childVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        childVC.didMove(toParent: self)
        navigationItem.rightBarButtonItems = childVC.navigationItem.rightBarButtonItems
            ?? [childVC.navigationItem.rightBarButtonItem].compactMap { $0 }
    }
}
#endif
