import Foundation
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

public class SpotARNavigationViewController {
    private var navigationViewController: NavigationViewController!
    private var routes: [Route]?
    
    public var delegate: SpotARNavigationUIDelegate?
    
    public init() {}
    
    public func startNavigation(routes: [Route], simulated: Bool = false) {
        guard let route = routes.first else { return }
        self.routes = routes
        
        navigationViewController = NavigationViewController(
            for: route,
            locationManager: getNavigationLocationManager(simulated: simulated)
        )
        navigationViewController.delegate = self
        customStyleMap()
//        addSubViewMap()
        addListenerMap()
        delegate?.wantsToPresent(viewController: navigationViewController)
    }
    
    @objc private func customButtonTapped() {
        let latitude: CLLocationDegrees = navigationViewController.mapView?.userLocation!.location?.coordinate.latitude ?? 10.832158
        let longitude: CLLocationDegrees = (navigationViewController.mapView?.userLocation!.location?.coordinate.longitude) ?? 106.714004

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        navigationViewController.mapView?.setCenter(coordinate, zoomLevel: 20, animated: true)
    }
    
    @objc func progressDidReroute(_ notification: Notification) {
        if let userInfo = notification.object as? RouteController {
            navigationViewController.mapView?.showRoutes([userInfo.routeProgress.route])
        }
   }
    
    @objc func progressDidChange(_ notification: NSNotification  ) {
        let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as! RouteProgress
        let location = notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as! CLLocation
    
        addManeuverArrow(routeProgress)
        updateUserPuck(location)
        readjustMapCenter()
    }
    
    private func addManeuverArrow(_ routeProgress: RouteProgress) {
        if routeProgress.currentLegProgress.followOnStep != nil {
            navigationViewController.mapView?.addArrow(route: routeProgress.route, legIndex: routeProgress.legIndex, stepIndex: routeProgress.currentLegProgress.stepIndex + 1)
        } else {
            navigationViewController.mapView?.removeArrow()
        }
    }
    
    private func updateUserPuck(_ location: CLLocation) {
        navigationViewController.mapView?.updateCourseTracking(location: location, animated: true)
    }
    
    private func readjustMapCenter() {
        if navigationViewController.mapView != nil {
            let halfMapHeight = navigationViewController.mapView!.bounds.height / 2
            let topPadding = halfMapHeight - 30
            navigationViewController.mapView?.setContentInset(UIEdgeInsets(top: topPadding, left: 0, bottom: 0, right: 0), animated: true, completionHandler: nil)
        }
    }
    
    private func getNavigationLocationManager(simulated: Bool) -> NavigationLocationManager {
        guard let route = routes?.first else { return NavigationLocationManager() }
        return simulated ? SimulatedLocationManager(route: route) : NavigationLocationManager()
    }
    
    private func customStyleMap() {
        navigationViewController.mapView?.styleURL = URL(string: "https://api.maptiler.com/maps/streets/style.json?key=AVXR2vOTw3aGpqw8nlv2");
        navigationViewController.mapView?.routeLineColor = UIColor.red
    }

    private func addSubViewMap() {
        let customButton = UIButton()
        customButton.frame = CGRect(x: 50, y: 50, width: 150, height: 150)
        customButton.setTitle("Customz", for: .normal)
        customButton.setTitleColor(UIColor.white, for: .normal)
        customButton.backgroundColor = UIColor.blue
        customButton.addTarget(self, action: #selector(customButtonTapped), for: .touchUpInside)
        navigationViewController.mapView?.addSubview(customButton)
        navigationViewController.mapView?.bringSubviewToFront(customButton)
        navigationViewController.routeController.reroutesProactively = true
    }
    
    private func addListenerMap() {
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_ :)), name: .routeControllerProgressDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidReroute(_ :)), name: .routeControllerDidReroute, object: nil)
    }
}
