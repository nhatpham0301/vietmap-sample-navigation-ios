import UIKit
import MapboxNavigation

public protocol SpotARNavigationUIDelegate {
    func wantsToPresent(viewController: NavigationViewController) -> Void
    func didArrive(viewController: NavigationViewController) -> Void
    func didCancel() -> Void
}
