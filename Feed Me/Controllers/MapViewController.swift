/// Copyright (c) 2020 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import GoogleMaps

class MapViewController: UIViewController {
  @IBOutlet private weak var mapCenterPinImage: UIImageView!
  @IBOutlet private weak var pinImageVerticalConstraint: NSLayoutConstraint!
  @IBOutlet weak var mapView: GMSMapView!
  @IBOutlet weak var addressLabel: UILabel!
  
  let dataProvider = GoogleDataProvider()
  let searchRadius: Double = 1000
  
  var searchedTypes = ["bakery", "bar", "cafe", "grocery_or_supermarket", "restaurant"]
  
  let locationManager = CLLocationManager()
  
  func reverseGeocode(coordinate: CLLocationCoordinate2D) {
    let geocoder = GMSGeocoder()
    
    geocoder.reverseGeocodeCoordinate(coordinate) { (response, error) in
      self.addressLabel.unlock()
      
      guard let address = response?.firstResult(),
            let lines = address.lines else {
          return
      }
      
      self.addressLabel.text = lines.joined(separator: "\n")
      
      let labelHeight = self.addressLabel.intrinsicContentSize.height
      let topInset = self.view.safeAreaInsets.top
      
      self.mapView.padding = UIEdgeInsets(top: topInset, left: 0, bottom: labelHeight, right: 0)
      
      UIView.animate(withDuration: 0.25) {
        //self.pinImageVerticalConstraint.constant = (labelHeight - topInset) * 0.5
        self.view.layoutIfNeeded()
      }
    }
  }
  
  func fetchPlaces(near coordinate: CLLocationCoordinate2D) {
    mapView.clear()
    
    dataProvider.fetchPlaces(
      near: coordinate,
      radius: searchRadius,
      types: searchedTypes)
      { (places) in
         places.forEach { (place) in
            let marker = PlaceMarker(place: place, availableTypes: self.searchedTypes)
            marker.map = self.mapView
         }
    }
  }
  
  @IBAction func tapRefreshMap(_ sender: UIBarButtonItem) {
    fetchPlaces(near: mapView.camera.target)
  }
}

// MARK: - Lifecycle
extension MapViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    
    locationManager.delegate = self
    mapView.delegate = self
    
    if CLLocationManager.locationServicesEnabled() {
      locationManager.requestLocation()
      
      mapView.isMyLocationEnabled = true
      mapView.settings.myLocationButton = true
    } else {
      locationManager.requestWhenInUseAuthorization()
    }
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard let navigationController = segue.destination as? UINavigationController,
          let controller = navigationController.topViewController as? TypesTableViewController else {
        return
    }
    
    controller.selectedTypes = searchedTypes
    controller.delegate = self
  }
}

// MARK: - TypesTableViewControllerDelegate
extension MapViewController: TypesTableViewControllerDelegate {
  func typesController(_ controller: TypesTableViewController, didSelectTypes types: [String]) {
    searchedTypes = controller.selectedTypes.sorted()
    dismiss(animated: true)
    
    fetchPlaces(near: mapView.camera.target)
  }
}

extension MapViewController: CLLocationManagerDelegate {
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    guard status == .authorizedWhenInUse else {
        return
    }
    
    locationManager.requestLocation()
    
    mapView.isMyLocationEnabled = true
    mapView.settings.myLocationButton = true
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.first else {
      return
    }
    
    mapView.camera = GMSCameraPosition(target: location.coordinate, zoom: 15, bearing: 0, viewingAngle: 0)
    
    fetchPlaces(near: location.coordinate)
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print(error)
  }
}

extension MapViewController : GMSMapViewDelegate {
  
  func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
    self.reverseGeocode(coordinate: position.target)
  }
  
  func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
    self.addressLabel.lock()
    
    if gesture {
      mapCenterPinImage.fadeIn(0.25)
      mapView.selectedMarker = nil
    }
  }
  
  func mapView(_ mapView: GMSMapView, markerInfoContents marker: GMSMarker) -> UIView? {
    guard let placeMarker = marker as? PlaceMarker else {
      return nil
    }
    
    guard let infoView = UIView.viewFromNibName("MarkerInfoView") as? MarkerInfoView else {
      return nil
    }
    
    infoView.nameLabel.text = placeMarker.place.name
    infoView.addressLabel.text = placeMarker.place.address
    
    return infoView
  }
  
  func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
    mapCenterPinImage.fadeOut(0.25)
    return false
  }
  
  func didTapMyLocationButton(for mapView: GMSMapView) -> Bool {
    mapCenterPinImage.fadeIn(0.25)
    mapView.selectedMarker = nil
    return false
  }
}
