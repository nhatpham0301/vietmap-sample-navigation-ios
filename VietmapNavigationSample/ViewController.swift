import UIKit
import VietMapCoreNavigation
import VietMapNavigation
import MapboxDirections
import UserNotifications
import MapKit
import SearchTextField

private typealias RouteRequestSuccess = (([Route]) -> Void)
private typealias RouteRequestFailure = ((NSError) -> Void)


class ViewController: UIViewController, MGLMapViewDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet weak var longPressHintView: UIView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var bottomBar: UIView!
    @IBOutlet weak var clearMap: UIButton!
    @IBOutlet weak var bottomBarBackground: UIView!
    @IBOutlet weak var searchLocation: SearchTextField!
    @IBOutlet weak var clearMapV: UIButton!
    
    var navigationViewController: SpotARNavigationViewController?
    var navigationCustomController: CustomUINavigationController?
    var navigationView: NavigationViewController?
    var mapboxRouteController: RouteController?
    let url = Bundle.main.object(forInfoDictionaryKey: "VietMapURL") as! String
    let keySearch = Bundle.main.object(forInfoDictionaryKey: "VietMapAccessToken") as! String
    
    var arrivel: CLLocationCoordinate2D?
    
    // MARK: Properties
    var mapView: NavigationMapView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let mapView = mapView {
                configureMapView(mapView)
                view.insertSubview(mapView, belowSubview: longPressHintView)
            }
        }
    }

    var waypoints: [Waypoint] = [] {
        didSet {
            waypoints.forEach {
                $0.coordinateAccuracy = -1
            }
        }
    }

    var routes: [Route]? {
        didSet {
            startButton.isEnabled = (routes?.count ?? 0 > 0)
            guard let routes = routes,
                  let current = routes.first else { mapView?.removeRoutes(); return }

            mapView?.showRoutes(routes)
            mapView?.showWaypoints(current)
        }
    }
    
    var responseSearch: [Response]?

    // MARK: Directions Request Handlers
    @objc public var overheadInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 20, left: 20, bottom: 70, right: 20)
    }

    fileprivate lazy var defaultSuccess: RouteRequestSuccess = { [weak self] (routes) in
        guard let current = routes.first else { return }
        self?.mapView?.removeWaypoints()
        self?.routes = routes
        self?.waypoints = current.routeOptions.waypoints
        self?.clearMapV.isEnabled = true
        self?.longPressHintView.isHidden = true
        self?.mapView?.setOverheadCameraView(from: (self?.waypoints.first!.coordinate)!, along: current.coordinates!, for: self!.overheadInsets)
    }

    fileprivate lazy var defaultFailure: RouteRequestFailure = { [weak self] (error) in
        self?.routes = nil //clear routes from the map
        print(error.localizedDescription)
    }

    var alertController: UIAlertController!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startMapView()
        configSearch()
        let textAttributes = [NSAttributedString.Key.foregroundColor:UIColor.systemBlue]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { _,_ in
                DispatchQueue.main.async {
                    CLLocationManager().requestWhenInUseAuthorization()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        alertController = UIAlertController(title: "Bắt đầu điều hướng", message: "Chọn kiểu điều hướng", preferredStyle: .actionSheet)
        typealias ActionHandler = (UIAlertAction) -> Void
        let defaultS: ActionHandler = {_ in self.startDefaultNavigation() }
        let customS: ActionHandler = {_ in self.startCustomSNavigation() }
        
        let actionPayloads: [(String, UIAlertAction.Style, ActionHandler?)] = [
            ("Default UI", .default, defaultS),
            ("Custom UI", .default, customS),
            ("Cancel", .cancel, nil),
        ]
        
        actionPayloads
            .map { payload in UIAlertAction(title: payload.0, style: payload.1, handler: payload.2)}
            .forEach(alertController.addAction(_:))
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = self.startButton
        }
        
    }
    
    func showLoading() {
        let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)

        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.medium
        loadingIndicator.startAnimating();

        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
    }
    
    func hideLoading() {
        dismiss(animated: false, completion: nil)
    }
    
    @objc func backButtonTapped() {
        searchLocation.resignFirstResponder()
    }
    
    func configSearch() {
        searchLocation.delegate = self
        searchLocation.theme.fontColor = UIColor.white
        searchLocation.theme.subtitleFontColor = UIColor.white
        searchLocation.theme.font = UIFont.systemFont(ofSize: 16)
        searchLocation.theme.separatorColor = UIColor (red: 0.9, green: 0.9, blue: 0.9, alpha: 0.5)
        searchLocation.theme.bgColor = hexStringToUIColor(hex: "#4d4d4d")
        searchLocation.theme.cellHeight = 50
        searchLocation.highlightAttributes = [NSAttributedString.Key.backgroundColor: UIColor.gray, NSAttributedString.Key.font:UIFont.boldSystemFont(ofSize: 16)]
        searchLocation.startVisible = true
        searchLocation.forceNoFiltering = true

        // add sub button
        searchLocation.clearButtonMode = .whileEditing
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "arrow.backward"), for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        searchLocation.leftView = backButton
        searchLocation.leftViewMode = .whileEditing

        // handle with route
        searchLocation.itemSelectionHandler = { filteredResults, itemPosition in
            // Just in case you need the item position
            let item = filteredResults[itemPosition]
            // Do whatever you want with the picked item
            self.searchLocation.text = item.title
            self.loadLatLong(self.responseSearch?[itemPosition].refID ?? "") { results in
                if results != nil {
                    self.handleRequestRoute(arrivel: results!)
                }
            }
            self.searchLocation.keyboardIsShowing = false
            self.view.endEditing(true)
        }
        
        searchLocation.userStoppedTypingHandler = {
            if let location = self.searchLocation.text {
                // Show the loading indicator
                if location.count > 1 {
                    self.searchLocation.showLoadingIndicator()
                    
                    self.loadLocation(location) { results in
                        self.searchLocation.filterItems(results)
                        self.searchLocation.stopLoadingIndicator()
                    }
                }
            }
        } as (() -> Void)
    }
    
    func startDefaultNavigation() {
        navigationViewController = SpotARNavigationViewController()
        navigationViewController?.delegate = self
        navigationViewController?.startNavigation(routes: routes!, simulated: false)
    }
    
    func startCustomSNavigation() {
        guard let route = routes?.first else { return }
        let storyboard = UIStoryboard.init(name: "CustomView", bundle: nil)
        guard let customViewController = storyboard.instantiateViewController(identifier: "custom") as? CustomUINavigationController else {return}
        customViewController.userRoute = route
        customViewController.arrivel = arrivel
        customViewController.simulateLocation = false
        present(customViewController, animated: true, completion: nil)
    }

    // MARK: Gesture Recognizer Handlers
    @objc func didLongPress(tap: UILongPressGestureRecognizer) {
        guard let mapView = mapView, tap.state == .began else { return }

        if let annotation = mapView.annotations?.last, waypoints.count > 2 {
            mapView.removeAnnotation(annotation)
        }
        handleRequestRoute(arrivel: mapView.convert(tap.location(in: mapView), toCoordinateFrom: mapView))
    }
    
    func handleRequestRoute(arrivel: CLLocationCoordinate2D) {
        self.showLoading()
        waypoints.removeAll()
        self.arrivel = arrivel
        let waypoint = Waypoint(coordinate: arrivel, name: "Điểm đến của bạn")
        waypoints.append(waypoint)
        requestRoute()
    }

    @IBAction func clearMapPressed(_ sender: Any) {
        clearMap.isHidden = true
        mapView?.removeRoutes()
        mapView?.removeWaypoints()
        waypoints.removeAll()
        longPressHintView.isHidden = false
        self.searchLocation.text = nil
        mapView?.userTrackingMode = .follow
    }

    @IBAction func clearMapPressedV(_ sender: Any) {
        clearMapV.isEnabled = false
        mapView?.removeRoutes()
        mapView?.removeWaypoints()
        waypoints.removeAll()
        longPressHintView.isHidden = false
        self.searchLocation.text = nil
//        mapView?.userTrackingMode = .follow
        mapView?.recenterMap()
    }

    @IBAction func startButtonPressed(_ sender: Any) {
        present(alertController, animated: true, completion: nil)
    }

    // MARK: - Public Methods
    // MARK: Route Requests
    func requestRoute() {
        guard waypoints.count > 0 else { return }
        guard let mapView = mapView else { return }
        let userWaypoint = Waypoint(location: mapView.userLocation!.location!, heading: mapView.userLocation?.heading, name: "User location")
        userWaypoint.headingAccuracy = 60
        if userWaypoint.heading != nil {
            userWaypoint.heading = Double(Int(ceil(userWaypoint.heading)))
        }
        waypoints.insert(userWaypoint, at: 0)

        let routeOptions = NavigationRouteOptions(waypoints: waypoints, profileIdentifier: .automobile)
        routeOptions.shapeFormat = .polyline6
        requestRoute(with: routeOptions, success: defaultSuccess, failure: defaultFailure)
    }

    fileprivate func requestRoute(with options: RouteOptions, success: @escaping RouteRequestSuccess, failure: RouteRequestFailure?) {
        let handler: Directions.RouteCompletionHandler = {(waypoints, potentialRoutes, potentialError) in
            self.hideLoading()
            if let error = potentialError, let fail = failure { return fail(error) }
            guard let routes = potentialRoutes else { return }
            return success(routes)
        }
        let apiUrl = Directions.shared.url(forCalculating: options)
        print("API Request URL: \(apiUrl)")
        Directions.shared.calculate(options, completionHandler: handler)
    }

    func presentAndRemoveMapview(_ viewController: NavigationViewController) {
        self.navigationView = viewController
        present(viewController, animated: true) {
            self.mapView?.removeFromSuperview()
            self.mapView = nil
        }
    }
    
    func startMapView(_ beganMap: Bool = true) {
        if beganMap {
            self.routes = nil
            self.waypoints = []
        }
        self.mapView = NavigationMapView(frame: view.bounds,styleURL: URL(string: url))
        // Reset the navigation styling to the defaults if we are returning from a presentation.
        if (presentedViewController != nil) {
            DayStyle().apply()
        }
        Locale.localeVoice = "vi"
    }

    func configureMapView(_ mapView: NavigationMapView) {
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = self
        mapView.navigationMapDelegate = self
        mapView.userTrackingMode = .followWithHeading

        let singleTap = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(tap:)))
        mapView.gestureRecognizers?.filter({ $0 is UILongPressGestureRecognizer }).forEach(singleTap.require(toFail:))
        mapView.addGestureRecognizer(singleTap)
        
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe(swipe:)))
        mapView.addGestureRecognizer(swipe)
    }

    @objc func didSwipe(swipe: UISwipeGestureRecognizer) {
    }

    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        self.mapView?.localizeLabels()
        
        if let routes = routes, let currentRoute = routes.first, let coords = currentRoute.coordinates {
            mapView.setVisibleCoordinateBounds(MGLPolygon(coordinates: coords, count: currentRoute.coordinateCount).overlayBounds, animated: false)
            self.mapView?.showRoutes(routes)
            self.mapView?.showWaypoints(currentRoute)
        }
    }
    
    func mapView(_ mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
        // Xử lý sự kiện di chuyển MapView tại đây
        print("move map")
    }
    
    func mapViewWillStartLoadingMap(_ mapView: MGLMapView) {
        // Xử lý sự kiện tại đây
        print("Bản đồ bắt đầu tải...")
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
            // Xử lý sự kiện tại đây
        print("Bản đồ đã hoàn thành tải và hiển thị.")
    }
    
    func mapViewWillStartRenderingMap(_ mapView: MGLMapView) {
            // Xử lý sự kiện tại đây
        print("Bản đồ đã rerender.")
    }
    
    func hexStringToUIColor (hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return UIColor.gray
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    fileprivate func loadLocation(_ location: String, callback: @escaping ((_ results: [SearchTextFieldItem]) -> Void)) {
        let userLocation = self.mapView?.userLocation?.location
        var urlString = "https://maps.vietmap.vn/api/search/v3?apikey=\(keySearch)&text=\(location)"
        if let latlongLocation = userLocation?.coordinate {
            urlString += "&focus=\(latlongLocation.latitude),\(latlongLocation.longitude)"
        }
        print(urlString)
        let search = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        let url = URL(string:search!)

        if let url = url {
            let task = URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
                do {
                    if let data = data {
                        let decoder = JSONDecoder()
                        self.responseSearch = try decoder.decode([Response].self, from: data)
                        var results = [SearchTextFieldItem]()
                        for result in self.responseSearch ?? [] {
                            results.append(SearchTextFieldItem(title: result.name, subtitle: result.display))
                        }
                        DispatchQueue.main.async {
                            callback(results)
                        }
                    } else {
                        DispatchQueue.main.async {
                            callback([])
                        }
                    }
                }
                catch {
                    print("Network error: \(error)")
                    DispatchQueue.main.async {
                        callback([])
                    }
                }
            })
            
            task.resume()
        }
    }
    
    fileprivate func loadLatLong(_ refID: String, callback: @escaping ((_ results: CLLocationCoordinate2D?) -> Void)) {
        let urlString = "https://maps.vietmap.vn/api/place/v3?apikey=\(keySearch)&refid=\(refID)"
        let search = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        let url = URL(string:search!)
        
        if let url = url {
            let task = URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
                do {
                    if let data = data {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(LocationVM.self, from: data)
                        let result = CLLocationCoordinate2D(latitude: response.latitude, longitude: response.longitude)
                        DispatchQueue.main.async {
                            callback(result)
                        }
                    } else {
                        DispatchQueue.main.async {
                            callback(nil)
                        }
                    }
                }
                catch {
                    print("Network error: \(error)")
                    DispatchQueue.main.async {
                        callback(nil)
                    }
                }
            })
            
            task.resume()
        }
    }
}

// MARK: - NavigationMapViewDelegate
extension ViewController: NavigationMapViewDelegate {
    func navigationMapView(_ mapView: NavigationMapView, didSelect waypoint: Waypoint) {
        guard let routeOptions = routes?.first?.routeOptions else { return }
        let modifiedOptions = routeOptions.without(waypoint: waypoint)

        presentWaypointRemovalActionSheet { _ in
            self.requestRoute(with:modifiedOptions, success: self.defaultSuccess, failure: self.defaultFailure)
        }
    }

    func navigationMapView(_ mapView: NavigationMapView, didSelect route: Route) {
        guard let routes = routes else { return }
        guard let index = routes.firstIndex(where: { $0 == route }) else { return }
        self.routes!.remove(at: index)
        self.routes!.insert(route, at: 0)
    }

    private func presentWaypointRemovalActionSheet(completionHandler approve: @escaping ((UIAlertAction) -> Void)) {
        let title = NSLocalizedString("Remove Waypoint?", comment: "Waypoint Removal Action Sheet Title")
        let message = NSLocalizedString("Would you like to remove this waypoint?", comment: "Waypoint Removal Action Sheet Message")
        let removeTitle = NSLocalizedString("Remove Waypoint", comment: "Waypoint Removal Action Item Title")
        let cancelTitle = NSLocalizedString("Cancel", comment: "Waypoint Removal Action Sheet Cancel Item Title")

        let actionSheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        let remove = UIAlertAction(title: removeTitle, style: .destructive, handler: approve)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)
        [remove, cancel].forEach(actionSheet.addAction(_:))

        self.present(actionSheet, animated: true, completion: nil)
    }
}

extension ViewController: SpotARNavigationUIDelegate {
    func wantsToPresent(viewController: VietMapNavigation.NavigationViewController) {
        presentAndRemoveMapview(viewController)
    }
    
    func didArrive(viewController: VietMapNavigation.NavigationViewController) {
        print("did Arrive")
        if (self.navigationViewController != nil) {
            self.navigationViewController?.cancelListener()
        }
    }
    
    func didCancel() {
        print("did Cancel")
        if (self.navigationViewController != nil) {
            self.navigationViewController?.cancelListener()
        }
        self.navigationView?.dismiss(animated: true) {
            self.searchLocation.text = nil
            self.startMapView(false)
        }
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        self.waypoints.removeAll()
        self.mapView?.removeRoutes()
        return true
    }
}
