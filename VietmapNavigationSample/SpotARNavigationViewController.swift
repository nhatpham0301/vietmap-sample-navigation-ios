import Foundation
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

public class SpotARNavigationViewController {
    private var navigationViewController: NavigationViewController!
    private var mapboxRouteController: RouteController?
    private var routes: [Route]?
    
    public var delegate: SpotARNavigationUIDelegate?
    
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
        addSubViewMap()
        addListenerMap()
        addListenerCamera(simulated: simulated)
        delegate?.wantsToPresent(viewController: navigationViewController)
    }
    
    @objc private func customButtonTapped() {
        
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
        let simulatedLocationManager = SimulatedLocationManager(route: route)
       simulatedLocationManager.speedMultiplier = 5
        return simulated ? simulatedLocationManager : NavigationLocationManager()
    }
    
    private func configureMapView(_ mapView: NavigationMapView) {
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.userTrackingMode = .follow
        mapView.logoView.isHidden = true
    }

    private func customStyleMap() {
        navigationViewController.mapView?.styleURL = URL(string: "https://api.maptiler.com/maps/streets/style.json?key=AVXR2vOTw3aGpqw8nlv2");
        navigationViewController.mapView?.routeLineColor = UIColor.red
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
        navigationViewController.routeController.reroutesProactively = true
    }
    
    private func addListenerMap() {
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_ :)), name: .routeControllerProgressDidChange, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidReroute(_ :)), name: .routeControllerDidReroute, object: nil)
    }
    
    private func addListenerCamera(simulated: Bool = false) {
        guard let route = routes?.first else { return }
        let mapboxRouteController = RouteController(
            along: route,
            directions: Directions.shared,
            locationManager: getNavigationLocationManager(simulated: simulated))
        self.mapboxRouteController = mapboxRouteController
        mapboxRouteController.delegate = self
        mapboxRouteController.resume()
    }
    
    deinit {
            // Hủy đăng ký lắng nghe sự kiện khi view controller bị hủy
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
        mapboxRouteController?.delegate = nil
    }
}

// MARK: Route Controller Delegate
extension SpotARNavigationViewController: RouteControllerDelegate {
    @objc public func routeController(_ routeController: RouteController, didUpdate locations: [CLLocation]) {
        guard let location = locations.first else { return }
        let camera = MGLMapCamera(
            lookingAtCenter: location.coordinate,
            acrossDistance: 500,
            pitch: 75,
            heading: location.course
        )
        self.navigationViewController.mapView?.setCamera(camera, animated: true)
    }
    
    @objc func didPassVisualInstructionPoint(notification: NSNotification) {
        guard let currentVisualInstruction = currentStepProgress(from: notification)?.currentVisualInstruction else { return }
        
        print(String(
            format: "didPassVisualInstructionPoint primary text: %@ and secondary text: %@",
            String(describing: currentVisualInstruction.primaryInstruction.text),
            String(describing: currentVisualInstruction.secondaryInstruction?.text)))
    }
    
    @objc func didPassSpokenInstructionPoint(notification: NSNotification) {
        guard let currentSpokenInstruction = currentStepProgress(from: notification)?.currentSpokenInstruction else { return }
        
        print("didPassSpokenInstructionPoint text: \(currentSpokenInstruction.text)")
    }
    
    private func currentStepProgress(from notification: NSNotification) -> RouteStepProgress? {
        let routeProgress = notification.userInfo?[RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress
        return routeProgress?.currentLegProgress.currentStepProgress
    }
}
