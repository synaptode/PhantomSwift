import XCTest
@testable import PhantomSwift

final class PhantomFeatureCatalogTests: XCTestCase {

    func testEveryFeatureHasNonEmptyPresentationDescriptor() {
        for feature in PhantomFeature.allCases {
            let descriptor = PhantomFeatureCatalog.descriptor(for: feature)

            XCTAssertFalse(descriptor.title.isEmpty, "Expected non-empty title for \(feature.rawValue)")
            XCTAssertFalse(descriptor.icon.isEmpty, "Expected non-empty icon for \(feature.rawValue)")
        }
    }

    func testFeatureTitlesAreUniqueAcrossCatalog() {
        let titles = PhantomFeature.allCases.map {
            PhantomFeatureCatalog.descriptor(for: $0).title
        }

        XCTAssertEqual(Set(titles).count, titles.count)
    }

    func testUIInspectorUsesPresentationContextRootView() {
        let rootView = UIView()
        let descriptor = PhantomFeatureCatalog.descriptor(for: .uiInspector)

        let viewController = descriptor.makeViewController(
            PhantomFeaturePresentationContext(inspectedRootView: rootView)
        )

        XCTAssertTrue(viewController is ViewHierarchyVC)
    }
}
