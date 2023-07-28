import UIKit
import VietMapNavigation

public protocol SpotARNavigationUIDelegate {
    func wantsToPresent(viewController: NavigationViewController) -> Void
    func didArrive(viewController: NavigationViewController) -> Void
    func didCancel() -> Void
}
