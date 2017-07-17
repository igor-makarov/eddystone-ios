import CoreBluetooth

open class Beacon {
    
    //MARK: Enumerations
    public enum SignalStrength: Int {
        case excellent
        case veryGood
        case good
        case low
        case veryLow
        case noSignal
        case unknown
    }
    
    //MARK: Frames
    var frames: (
        url: UrlFrame?,
        uid: UidFrame?,
        tlm: TlmFrame?
    ) = (nil,nil,nil)
    
    //MARK: Properties
    var txPower: Int
    public var identifier: String
    public var rssi: Double {
        get {
            if self.rssiBuffer.isEmpty {
                return 0
            }
            
            var totalRssi: Double = 0
            for rssi in self.rssiBuffer {
                totalRssi += Double(rssi)
            }
            
            let average: Double = totalRssi / Double(self.rssiBuffer.count)
            return average
        }
    }
    var signalStrength: SignalStrength = .unknown
    var rssiBuffer = [Int]()
    var distance: Double {
        get {
            return Beacon.calculateAccuracy(txPower: self.txPower, rssi: self.rssi)
        }
    }
    
    //MARK: Initializations
    init(rssi: Int, txPower: Int, identifier: String) {
        self.txPower = txPower
        self.identifier = identifier
        
        self.updateRssi(rssi)
    }
    
    //MARK: Delegate
    var delegate: BeaconDelegate?
    func notifyChange() {
        self.delegate?.beaconDidChange()
    }
    
    //MARK: Functions
    func updateRssi(_ newRssi: Int) {
        if (newRssi == 127) {
            return
        }
        self.rssiBuffer.insert(newRssi, at: 0)
        if self.rssiBuffer.count > 1 {
            self.rssiBuffer.removeLast()
        }
        
        let signalStrength = Beacon.calculateSignalStrength(self.distance)
        if signalStrength != self.signalStrength {
            self.signalStrength = signalStrength
            self.notifyChange()
        }
        
    }
    
    //MARK: Calculations
    class func calculateAccuracy(txPower: Int, rssi: Double) -> Double {
        if rssi == 0 {
            return 0
        }
        
        let ratio: Double = rssi / Double(txPower)
        if ratio < 1 {
            return pow(ratio, 10)
        } else {
            return 0.89976 * pow(ratio, 7.7095) + 0.111
        }
        
    }
    
    class func calculateSignalStrength(_ distance: Double) -> SignalStrength {
        switch distance {
        case 0...24999:
            return .excellent
        case 25000...49999:
            return .veryGood
        case 50000...74999:
            return .good
        case 75000...99999:
            return .low
        default:
            return .veryLow
        }
    }
    
    //MARK: Advertisement Data
    func parseAdvertisementData(_ advertisementData: [AnyHashable: Any], rssi: Int) {
        self.updateRssi(rssi)

        if let bytes = Beacon.bytesFromAdvertisementData(advertisementData) {
            if let type = Beacon.frameTypeFromBytes(bytes) {
                switch type {
                case .url:
                    if let frame = UrlFrame.frameWithBytes(bytes) {
                        if frame.url != self.frames.url?.url {
                            self.frames.url = frame
                            log("Parsed URL Frame with url: \(frame.url) Distance: \(String(format: "%.2f", distance)) (-\(-rssi)/\(-txPower))")
                            self.notifyChange()
                        }
                    }
                case .uid:
                    if let frame = UidFrame.frameWithBytes(bytes) {
                        if frame.uid != self.frames.uid?.uid {
                            self.frames.uid = frame
                            log("Parsed UID Frame with uid: \(frame.uid) Distance: \(String(format: "%.2f", distance)) (-\(-rssi)/\(-txPower))")
                            self.notifyChange()
                        }
                    }
                case .tlm:
                    if let frame = TlmFrame.frameWithBytes(bytes) {
                        self.frames.tlm = frame
                        log("Parsed TLM Frame with battery: \(frame.batteryVolts) temperature: \(frame.temperature) advertisement count: \(frame.advertisementCount) on time: \(frame.onTime) Distance: \(String(format: "%.2f", distance)) (-\(-rssi)/\(-txPower))")
                        self.notifyChange()
                    }
                }
            }
        }
    }
    
    //MARK: Bytes
    class func beaconWithAdvertisementData(_ advertisementData: [AnyHashable: Any], rssi: Int, identifier: String) -> Beacon? {
        var txPower: Int?
        var type: FrameType?

        if let bytes = Beacon.bytesFromAdvertisementData(advertisementData) {
            type = Beacon.frameTypeFromBytes(bytes)
            txPower = Beacon.txPowerFromBytes(bytes)
            
            if let txPower = txPower, type != nil {
                let beacon = Beacon(rssi: rssi, txPower: txPower, identifier: identifier)
                beacon.parseAdvertisementData(advertisementData, rssi: rssi)
                return beacon
            }
            
        }
        
        return nil
    }
    
    class func bytesFromAdvertisementData(_ advertisementData: [AnyHashable: Any]) -> [Byte]? {
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [AnyHashable: Any] {
            if let urlData = serviceData[Scanner.eddystoneServiceUUID] as? Data {
                let count = urlData.count / MemoryLayout<UInt8>.size
                var bytes = [UInt8](repeating: 0, count: count)
                (urlData as NSData).getBytes(&bytes, length:count * MemoryLayout<UInt8>.size)
                return bytes.map { byte in
                    return Byte(byte)
                }
            }
        }
        
        return nil
    }
    
    class func frameTypeFromBytes(_ bytes: [Byte]) -> FrameType? {
        if bytes.count >= 1 {
            switch bytes[0] {
            case 0:
                return .uid
            case 16:
                return .url
            case 32:
                return .tlm
            default:
                break
            }
        }
        
        return nil
    }
    
    class func txPowerFromBytes(_ bytes: [Byte]) -> Int? {
        if bytes.count >= 2 {
            if let type = Beacon.frameTypeFromBytes(bytes) {
                if type == .uid || type == .url {
                    return Int(Int8(bitPattern: UInt8(bytes[1])))
                }
            }
        }
        
        return nil
    }
}

protocol BeaconDelegate {
    func beaconDidChange()
}

