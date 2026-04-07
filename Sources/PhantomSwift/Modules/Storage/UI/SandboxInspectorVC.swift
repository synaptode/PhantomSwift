#if DEBUG
import UIKit

/// File browser for the app's sandbox.
internal final class SandboxInspectorVC: PhantomTableVC {

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt
    }()
    private let currentPath: String
    private var contents: [URL] = []
    
    internal init(path: String = NSHomeDirectory()) {
        self.currentPath = path
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = (currentPath as NSString).lastPathComponent
        loadContents()
    }
    
    private func loadContents() {
        let url = URL(fileURLWithPath: currentPath)
        do {
            contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: .skipsHiddenFiles)
        } catch {
            print("Error loading sandbox contents: \(error)")
        }
        tableView.reloadData()
    }
    
    // MARK: - TableView
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contents.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FileCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "FileCell")
        let url = contents[indexPath.row]
        
        cell.backgroundColor = .clear
        
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        cell.textLabel?.text = url.lastPathComponent
        cell.textLabel?.textColor = PhantomTheme.shared.textColor
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        
        if #available(iOS 13.0, *) {
            let iconName: String
            let iconColor: UIColor
            if isDir {
                iconName = "folder.fill"
                iconColor = .systemTeal
            } else {
                let ext = url.pathExtension.lowercased()
                if ext == "sqlite" || ext == "db" {
                    iconName = "database.fill"
                    iconColor = .systemPurple
                } else if ext == "plist" || ext == "json" {
                    iconName = "doc.text.fill"
                    iconColor = .systemBlue
                } else {
                    iconName = "doc.fill"
                    iconColor = .systemGray
                }
            }
            cell.imageView?.image = UIImage(systemName: iconName)
            cell.imageView?.tintColor = iconColor
        }
        
        if isDir {
            cell.detailTextLabel?.text = "Directory"
            cell.accessoryType = .disclosureIndicator
        } else {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            if let date = date {
                cell.detailTextLabel?.text = "\(sizeStr) • \(SandboxInspectorVC.dateFormatter.string(from: date))"
            } else {
                cell.detailTextLabel?.text = sizeStr
            }
            cell.accessoryType = .none
        }
        cell.detailTextLabel?.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 11)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let url = contents[indexPath.row]
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        
        if isDir {
            let nextVC = SandboxInspectorVC(path: url.path)
            navigationController?.pushViewController(nextVC, animated: true)
        } else {
            let ext = url.pathExtension.lowercased()
            if ext == "sqlite" || ext == "db" {
                let inspector = SQLiteInspectorVC(fileURL: url)
                navigationController?.pushViewController(inspector, animated: true)
            } else {
                // Future: Add text/image previewer
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let url = contents[indexPath.row]
            try? FileManager.default.removeItem(at: url)
            loadContents()
        }
    }
}
#endif
