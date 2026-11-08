#if DEBUG
import UIKit
#if canImport(WebKit)
import WebKit

extension WebViewInspectorVC {
    internal func setupUI() {
        modeSegmentedControl.selectedSegmentIndex = 0
        modeSegmentedControl.addTarget(self, action: #selector(didChangeMode), for: .valueChanged)
        modeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modeSegmentedControl)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            modeSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            modeSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            modeSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            containerView.topAnchor.constraint(equalTo: modeSegmentedControl.bottomAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.topAnchor.constraint(equalTo: modeSegmentedControl.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        setupLogsView()
        setupDOMView()
        setupREPLView()
        updateModeVisibility()
    }

    private func setupLogsView() {
        logsContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(logsContainer)

        logFilterControl.selectedSegmentIndex = 0
        logFilterControl.addTarget(self, action: #selector(didChangeLogFilter), for: .valueChanged)
        logFilterControl.translatesAutoresizingMaskIntoConstraints = false
        logsContainer.addSubview(logFilterControl)

        searchBar.placeholder = "Filter logs & bridge messages"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        logsContainer.addSubview(searchBar)

        logsTableView.backgroundColor = .clear
        logsTableView.separatorColor = PhantomTheme.shared.niagaraSeparator
        logsTableView.translatesAutoresizingMaskIntoConstraints = false
        logsContainer.addSubview(logsTableView)

        NSLayoutConstraint.activate([
            logsContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            logsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            logsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            logsContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            logFilterControl.topAnchor.constraint(equalTo: logsContainer.topAnchor, constant: 4),
            logFilterControl.leadingAnchor.constraint(equalTo: logsContainer.leadingAnchor, constant: 16),
            logFilterControl.trailingAnchor.constraint(equalTo: logsContainer.trailingAnchor, constant: -16),

            searchBar.topAnchor.constraint(equalTo: logFilterControl.bottomAnchor, constant: 4),
            searchBar.leadingAnchor.constraint(equalTo: logsContainer.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: logsContainer.trailingAnchor, constant: -8),

            logsTableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            logsTableView.leadingAnchor.constraint(equalTo: logsContainer.leadingAnchor),
            logsTableView.trailingAnchor.constraint(equalTo: logsContainer.trailingAnchor),
            logsTableView.bottomAnchor.constraint(equalTo: logsContainer.bottomAnchor)
        ])
    }

    private func setupDOMView() {
        domContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(domContainer)

        domHeaderCard.backgroundColor = PhantomTheme.shared.surfaceColor
        domHeaderCard.layer.cornerRadius = 10
        domHeaderCard.translatesAutoresizingMaskIntoConstraints = false
        domContainer.addSubview(domHeaderCard)

        domTitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        domTitleLabel.textColor = PhantomTheme.shared.textColor
        domTitleLabel.numberOfLines = 1
        domTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        domHeaderCard.addSubview(domTitleLabel)

        domUrlLabel.font = UIFont.phantomMonospaced(size: 11, weight: .regular)
        domUrlLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        domUrlLabel.numberOfLines = 2
        domUrlLabel.translatesAutoresizingMaskIntoConstraints = false
        domHeaderCard.addSubview(domUrlLabel)

        domFetchButton.setTitle("Fetch HTML", for: .normal)
        domFetchButton.setImage(UIImage.phantomSymbol("arrow.clockwise"), for: .normal)
        domFetchButton.backgroundColor = PhantomTheme.shared.primaryColor
        domFetchButton.setTitleColor(.white, for: .normal)
        domFetchButton.tintColor = .white
        domFetchButton.layer.cornerRadius = 8
        domFetchButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        domFetchButton.addTarget(self, action: #selector(didTapFetchDOM), for: .touchUpInside)
        domFetchButton.translatesAutoresizingMaskIntoConstraints = false
        domContainer.addSubview(domFetchButton)

        domSubSegment.selectedSegmentIndex = 0
        domSubSegment.addTarget(self, action: #selector(didChangeDOMSubSegment), for: .valueChanged)
        domSubSegment.translatesAutoresizingMaskIntoConstraints = false
        domContainer.addSubview(domSubSegment)

        domCodeView.translatesAutoresizingMaskIntoConstraints = false
        domContainer.addSubview(domCodeView)

        domScriptsTableView.backgroundColor = .clear
        domScriptsTableView.separatorColor = PhantomTheme.shared.niagaraSeparator
        domScriptsTableView.translatesAutoresizingMaskIntoConstraints = false
        domContainer.addSubview(domScriptsTableView)

        setupDOMConstraints()
    }

    private func setupDOMConstraints() {
        NSLayoutConstraint.activate([
            domContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            domContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            domContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            domContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            domHeaderCard.topAnchor.constraint(equalTo: domContainer.topAnchor, constant: 8),
            domHeaderCard.leadingAnchor.constraint(equalTo: domContainer.leadingAnchor, constant: 16),
            domHeaderCard.trailingAnchor.constraint(equalTo: domContainer.trailingAnchor, constant: -16),

            domTitleLabel.topAnchor.constraint(equalTo: domHeaderCard.topAnchor, constant: 10),
            domTitleLabel.leadingAnchor.constraint(equalTo: domHeaderCard.leadingAnchor, constant: 12),
            domTitleLabel.trailingAnchor.constraint(equalTo: domHeaderCard.trailingAnchor, constant: -12),

            domUrlLabel.topAnchor.constraint(equalTo: domTitleLabel.bottomAnchor, constant: 4),
            domUrlLabel.leadingAnchor.constraint(equalTo: domHeaderCard.leadingAnchor, constant: 12),
            domUrlLabel.trailingAnchor.constraint(equalTo: domHeaderCard.trailingAnchor, constant: -12),
            domUrlLabel.bottomAnchor.constraint(equalTo: domHeaderCard.bottomAnchor, constant: -10),

            domFetchButton.topAnchor.constraint(equalTo: domHeaderCard.bottomAnchor, constant: 8),
            domFetchButton.leadingAnchor.constraint(equalTo: domContainer.leadingAnchor, constant: 16),
            domFetchButton.trailingAnchor.constraint(equalTo: domContainer.trailingAnchor, constant: -16),
            domFetchButton.heightAnchor.constraint(equalToConstant: 38),

            domSubSegment.topAnchor.constraint(equalTo: domFetchButton.bottomAnchor, constant: 8),
            domSubSegment.leadingAnchor.constraint(equalTo: domContainer.leadingAnchor, constant: 16),
            domSubSegment.trailingAnchor.constraint(equalTo: domContainer.trailingAnchor, constant: -16),

            domCodeView.topAnchor.constraint(equalTo: domSubSegment.bottomAnchor, constant: 8),
            domCodeView.leadingAnchor.constraint(equalTo: domContainer.leadingAnchor, constant: 16),
            domCodeView.trailingAnchor.constraint(equalTo: domContainer.trailingAnchor, constant: -16),
            domCodeView.bottomAnchor.constraint(equalTo: domContainer.bottomAnchor, constant: -8),

            domScriptsTableView.topAnchor.constraint(equalTo: domSubSegment.bottomAnchor, constant: 8),
            domScriptsTableView.leadingAnchor.constraint(equalTo: domContainer.leadingAnchor),
            domScriptsTableView.trailingAnchor.constraint(equalTo: domContainer.trailingAnchor),
            domScriptsTableView.bottomAnchor.constraint(equalTo: domContainer.bottomAnchor)
        ])
    }

    private func setupREPLView() {
        replContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(replContainer)

        let replTitle = UILabel()
        replTitle.text = "Console REPL"
        replTitle.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        replTitle.textColor = PhantomTheme.shared.textColor
        replTitle.translatesAutoresizingMaskIntoConstraints = false
        replContainer.addSubview(replTitle)

        replInputView.backgroundColor = PhantomTheme.shared.surfaceColor
        replInputView.textColor = PhantomTheme.shared.textColor
        replInputView.font = UIFont.phantomMonospaced(size: 13, weight: .regular)
        replInputView.layer.cornerRadius = 8
        replInputView.text = "document.title"
        replInputView.translatesAutoresizingMaskIntoConstraints = false
        replContainer.addSubview(replInputView)

        replRunButton.setTitle("Evaluate Script", for: .normal)
        replRunButton.setImage(UIImage.phantomSymbol("play.fill"), for: .normal)
        replRunButton.backgroundColor = PhantomTheme.shared.accentColor
        replRunButton.setTitleColor(.white, for: .normal)
        replRunButton.tintColor = .white
        replRunButton.layer.cornerRadius = 8
        replRunButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        replRunButton.addTarget(self, action: #selector(didTapRunREPL), for: .touchUpInside)
        replRunButton.translatesAutoresizingMaskIntoConstraints = false
        replContainer.addSubview(replRunButton)

        replOutputView.translatesAutoresizingMaskIntoConstraints = false
        replContainer.addSubview(replOutputView)

        NSLayoutConstraint.activate([
            replContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            replContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            replContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            replContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            replTitle.topAnchor.constraint(equalTo: replContainer.topAnchor, constant: 8),
            replTitle.leadingAnchor.constraint(equalTo: replContainer.leadingAnchor, constant: 16),
            replTitle.trailingAnchor.constraint(equalTo: replContainer.trailingAnchor, constant: -16),

            replInputView.topAnchor.constraint(equalTo: replTitle.bottomAnchor, constant: 6),
            replInputView.leadingAnchor.constraint(equalTo: replContainer.leadingAnchor, constant: 16),
            replInputView.trailingAnchor.constraint(equalTo: replContainer.trailingAnchor, constant: -16),
            replInputView.heightAnchor.constraint(equalToConstant: 70),

            replRunButton.topAnchor.constraint(equalTo: replInputView.bottomAnchor, constant: 8),
            replRunButton.leadingAnchor.constraint(equalTo: replContainer.leadingAnchor, constant: 16),
            replRunButton.trailingAnchor.constraint(equalTo: replContainer.trailingAnchor, constant: -16),
            replRunButton.heightAnchor.constraint(equalToConstant: 38),

            replOutputView.topAnchor.constraint(equalTo: replRunButton.bottomAnchor, constant: 8),
            replOutputView.leadingAnchor.constraint(equalTo: replContainer.leadingAnchor, constant: 16),
            replOutputView.trailingAnchor.constraint(equalTo: replContainer.trailingAnchor, constant: -16),
            replOutputView.bottomAnchor.constraint(equalTo: replContainer.bottomAnchor, constant: -8)
        ])
    }

    internal func setupTableViews() {
        logsTableView.delegate = self
        logsTableView.dataSource = self
        logsTableView.register(WebViewLogCell.self, forCellReuseIdentifier: "WebViewLogCell")
        logsTableView.rowHeight = 72

        domScriptsTableView.delegate = self
        domScriptsTableView.dataSource = self
        domScriptsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ScriptCell")
        domScriptsTableView.rowHeight = 60
    }

    internal func updateModeVisibility() {
        logsContainer.isHidden = modeSegmentedControl.selectedSegmentIndex != 0
        domContainer.isHidden = modeSegmentedControl.selectedSegmentIndex != 1
        replContainer.isHidden = modeSegmentedControl.selectedSegmentIndex != 2
        updateDOMSubSegmentVisibility()
    }

    internal func updateDOMSubSegmentVisibility() {
        domCodeView.isHidden = domSubSegment.selectedSegmentIndex != 0
        domScriptsTableView.isHidden = domSubSegment.selectedSegmentIndex != 1
    }
}
#endif
#endif
