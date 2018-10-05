import Foundation
import UIKit
import CoreData

class TBACollectionViewController: UICollectionViewController, DataController {

    var persistentContainer: NSPersistentContainer
    var noDataViewController: NoDataViewController?

    var requestsArray: [URLSessionDataTask] = []

    // MARK: - Init

    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer

        super.init(collectionViewLayout: UICollectionViewFlowLayout())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.backgroundColor = .backgroundGray
        collectionView.delegate = self
        collectionView.registerReusableCell(BasicCollectionViewCell.self)
    }

}

extension Refreshable where Self: TBACollectionViewController {

    var requests: [URLSessionDataTask] {
        get {
            return requestsArray
        }
        set {
            requestsArray = newValue
        }
    }

    var refreshControl: UIRefreshControl? {
        get {
            return collectionView.refreshControl
        }
        set {
            collectionView.refreshControl = newValue
        }
    }

    var refreshView: UIScrollView {
        return collectionView
    }

}
