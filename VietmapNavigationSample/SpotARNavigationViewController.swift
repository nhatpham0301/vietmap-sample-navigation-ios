import Foundation
import VietMapCoreNavigation
import VietMapNavigation
import MapboxDirections
import CoreLocation

public class SpotARNavigationViewController {
    private var navigationViewController: NavigationViewController!
    private var mapboxRouteController: RouteController?
    private var routes: [Route]?
    public var delegate: SpotARNavigationUIDelegate?
    private var currentLocation: CLLocation!
    private var isFirstRender: Bool = false
    let url = Bundle.main.object(forInfoDictionaryKey: "VietMapURL") as! String
    
    public init() {}

    public func startNavigation(routes: [Route], simulated: Bool = false) {
        guard let route = routes.first else { return }
        self.routes = routes
         
        navigationViewController = NavigationViewController(
            for: route,
            styles: [NightStyle()],
            locationManager: getNavigationLocationManager(simulated: simulated)
        )
        navigationViewController.delegate = self
        customStyleMap()
        configureMapView()
        addListenerMap()
        delegate?.wantsToPresent(viewController: navigationViewController)
    }
    
    @objc private func customButtonTapped() {
        let camera = MGLMapCamera(
            lookingAtCenter: currentLocation.coordinate,
            acrossDistance: 1000,
            pitch: 0,
            heading: currentLocation.course
        )
        navigationViewController.mapView?.setCamera(camera, animated: true)
    }
    
    @objc func progressDidReroute(_ notification: Notification) {
        if let userInfo = notification.object as? RouteController, let location =  notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as? CLLocation {
            addManeuverArrow(userInfo.routeProgress)
            navigationViewController.mapView?.showRoutes([userInfo.routeProgress.route])
            navigationViewController.mapView?.recenterMap()
            navigationViewController.mapView?.updateCourseTracking(location: location, animated: true)
        }
   }
    
    @objc func progressDidChange(_ notification: NSNotification  ) {
        let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as! RouteProgress
        let location = notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as! CLLocation
        print("---------start get location-------------")
        print(location.coordinate)
        print("---------end   get location-------------")
        currentLocation = location
//        setCenterIsFirst(location)
        updateUserPuck(location)
        addManeuverArrow(routeProgress)
    }
    
    private func setCenterIsFirst(_ location: CLLocation) {
        if !isFirstRender {
            centerMap(location)
            isFirstRender = true
        }
    }
    
    private func centerMap(_ location: CLLocation) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let camera = MGLMapCamera(
                lookingAtCenter: location.coordinate,
                acrossDistance: 500,
                pitch: 75,
                heading: location.course
            )
            self.navigationViewController.mapView?.setCamera(camera, animated: true)
        }
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
        let simulatedLocationManager = SimulatedLocationManager(route: route)
        simulatedLocationManager.speedMultiplier = 2
        return simulated ? simulatedLocationManager : NavigationLocationManager()
    }
    
    private func configureMapView() {
        navigationViewController.mapView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationViewController.routeController.reroutesProactively = true
        self.navigationViewController.mapView?.tracksUserCourse = true
    }

    private func customStyleMap() {
        navigationViewController.mapView?.styleURL = URL(string: url);
        navigationViewController.mapView?.userTrackingMode = .follow
    }

    private func addSubViewMap() {
        let customButton = UIButton()
        customButton.frame = CGRect(x: UIScreen.main.bounds.width - 60, y:UIScreen.main.bounds.height - 250, width: 50, height: 50)
        customButton.setTitle("Center", for: .normal)
        customButton.setTitleColor(UIColor.blue, for: .normal)
        customButton.layer.cornerRadius = customButton.frame.height / 2
        customButton.clipsToBounds = true
        customButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        customButton.backgroundColor = UIColor.white
        customButton.addTarget(self, action: #selector(customButtonTapped), for: .touchUpInside)
        
        navigationViewController.mapView?.addSubview(customButton)
        navigationViewController.mapView?.bringSubviewToFront(customButton)
    }

    private func addListenerMap() {
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_ :)), name: .routeControllerProgressDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidReroute(_ :)), name: .routeControllerDidReroute, object: nil)
    }
    
    public func cancelListener() {
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
        mapboxRouteController?.delegate = nil
    }
}
