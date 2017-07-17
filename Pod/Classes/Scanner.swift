import CoreBluetooth

open class Scanner: NSObject {
    
    //MARK: Public
    open class func restoreCentralManager(identifier: String) {
        self.shared._centralManager = CBCentralManager(delegate: self.shared, queue: nil,
                                                       options: [CBCentralManagerOptionRestoreIdentifierKey : identifier])
    }
    
    open class func start() {
        self.shared._centralManager = CBCentralManager(delegate: self.shared, queue: nil, options:nil)
    }
    
    open class func stop() {
        self.shared._centralManager?.stopScan()
        self.shared._centralManager = nil
        self.shared.delegate = nil
    }
    
    //Returns an array of Url objects that are nearby
    open class var nearbyUrls: [Url] {
        get {
            var urls = [Url]()
            
            for beacon in self.beacons {
                if let urlFrame = beacon.frames.url {
                    let url = Url(url: urlFrame.url, signalStrength: beacon.signalStrength, identifier: beacon.identifier)
                    if let tlmFrame = beacon.frames.tlm {
                        url.parseTlmFrame(tlmFrame)
                    }
                    urls.append(url)
                }
            }
            
            return urls
        }
    }
    
    //Returns an array of Uid objects that are nearby
    open class var nearbyUids: [Uid] {
        get {
            var uids = [Uid]()
            
            for beacon in self.beacons {
                if let uidFrame = beacon.frames.uid {
                    let uid = Uid(namespace: uidFrame.namespace, instance: uidFrame.instance, signalStrength: beacon.signalStrength, identifier: beacon.identifier)
                    if let tlmFrame = beacon.frames.tlm {
                        uid.parseTlmFrame(tlmFrame)
                    }
                    uids.append(uid)
                }
            }
            
            return uids
        }
    }
    
    //Returns an array of all nearby Eddystone objects
    open class var nearby: [Generic] {
        get {
            var generics = [Generic]()
            
            for beacon in self.beacons {
                var url: URL?
                var namespace: String?
                var instance: String?
                
                if let uidFrame = beacon.frames.uid {
                    namespace = uidFrame.namespace
                    instance = uidFrame.instance
                }
                
                if let urlFrame = beacon.frames.url {
                    url = urlFrame.url as URL
                }
                
                let generic = Generic(url: url, namespace: namespace, instance: instance, signalStrength: beacon.signalStrength, rssi: Int(beacon.rssi), txPower: beacon.txPower, distance: beacon.distance, identifier: beacon.identifier)
                if let tlmFrame = beacon.frames.tlm {
                    generic.parseTlmFrame(tlmFrame)
                }
                generics.append(generic)
            }
            
            return generics

        }
    }
    
    //MARK: Singleton
    static let shared = Scanner()
    
    //MARK: Constants
    static let eddystoneServiceUUID = CBUUID(string: "FEAA")
    
    //MARK: Properties
    var _centralManager: CBCentralManager!
    var centralManager: CBCentralManager {
        return _centralManager
    }
    var discoveredBeacons = [String: Beacon]()
    var beaconTimers = [String: Timer]()
    
    //MARK: Delegate
    var delegate: ScannerDelegate?
    func notifyChange() {
        self.delegate?.eddystoneNearbyDidChange()
    }
    
    public class var delegate: ScannerDelegate? {
        get { return shared.delegate }
        set {
            shared.delegate = newValue
            shared.delegate?.eddystoneNearbyDidChange()
        }
    }
    
    //MARK: Internal Class
    public class var beacons: [Beacon] {
        get {
            var orderedBeacons = [Beacon]()
            
            for beacon in self.shared.discoveredBeacons.values {
                orderedBeacons.append(beacon)
            }
            
            orderedBeacons.sort { beacon1, beacon2 in
                return beacon1.distance < beacon2.distance
            }
            
            return orderedBeacons
        }
    }
    
}

extension Scanner: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            log("Bluetooth is powered on. Begin scan...")
            self.centralManager.scanForPeripherals(withServices: [Scanner.eddystoneServiceUUID], options:nil)
        } else {
            log("Bluetooth not powered on. Current state: \(central.state)")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let identifier = peripheral.identifier.uuidString

        let rssi = RSSI.intValue
        if let beacon = self.discoveredBeacons[identifier] {
            beacon.parseAdvertisementData(advertisementData, rssi: rssi)
        } else {
            if let beacon = Beacon.beaconWithAdvertisementData(advertisementData, rssi: rssi, identifier: identifier) {
                beacon.delegate = self
                self.discoveredBeacons[peripheral.identifier.uuidString] = beacon
                self.notifyChange()
            }
        }
        
        self.beaconTimers[identifier]?.invalidate()
        self.beaconTimers[identifier] = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(Scanner.beaconTimerExpire(_:)), userInfo: identifier, repeats: false)
    }
    
    @objc func beaconTimerExpire(_ timer: Timer) {
        if let identifier = timer.userInfo as? String {
            log("Beacon lost")
            
            self.discoveredBeacons.removeValue(forKey: identifier)
            self.notifyChange()
        }
    }
    
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        
    }
}

extension Scanner: BeaconDelegate {
    
    func beaconDidChange() {
        self.notifyChange()
    }
    
}

//MARK: Protocol
public protocol ScannerDelegate {
    
    func eddystoneNearbyDidChange()
    
}
