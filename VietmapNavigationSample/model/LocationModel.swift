struct Boundary: Codable {
    let type: Int
    let id: Int
    let name: String
    let prefix: String
    let fullName: String
    
    private enum CodingKeys: String, CodingKey {
        case type, id, name, prefix
        case fullName = "full_name"
    }
}

struct Response: Codable {
    let refID: String
    let address: String
    let name: String
    let display: String
    let boundaries: [Boundary]
    let categories: [String]
    
    private enum CodingKeys: String, CodingKey {
        case refID = "ref_id"
        case address, name, display, boundaries, categories
    }
}

struct LocationVM: Codable {
    let display: String
    let name: String
    let hsNum: String
    let street: String
    let address: String
    let cityID: Int
    let city: String
    let districtID: Int
    let district: String
    let wardID: Int
    let ward: String
    let latitude: Double
    let longitude: Double
    
    private enum CodingKeys: String, CodingKey {
        case display, name, hsNum = "hs_num", street, address, cityID = "city_id", city, districtID = "district_id", district, wardID = "ward_id", ward, latitude = "lat", longitude = "lng"
    }
}
