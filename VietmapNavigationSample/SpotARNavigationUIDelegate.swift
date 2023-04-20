import UIKit
import MapboxNavigation

public protocol SpotARNavigationUIDelegate {
    func wantsToPresent(viewController: NavigationViewController) -> Void
    func didArrive() -> Void
    func didCancel() -> Void
}
