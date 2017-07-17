open class Generic: Object {
   
    //MARK: Properties
    fileprivate(set) open var url: URL?
    fileprivate(set) open var namespace: String?
    fileprivate(set) open var instance: String?
    fileprivate(set) open var distance: Double
    fileprivate(set) open var rssi: Int
    fileprivate(set) open var txPower: Int
    open var uid: String? {
        get {
            if  let namespace = self.namespace,
                let instance = self.instance {
                    return namespace + instance
            }
            return nil
        }
    }
    
    //MARK: Initializations
    init(url: URL?, namespace: String?, instance: String?, signalStrength: Beacon.SignalStrength, rssi: Int, txPower: Int, distance: Double, identifier: String) {
        self.url = url
        self.namespace = namespace
        self.instance = instance
        self.distance = distance
        self.rssi = rssi
        self.txPower = txPower
        
        var urlString = ""
        if let absoluteString = url?.absoluteString {
            urlString = absoluteString
        }
        
        var uid = ""
        if  let namespace = self.namespace,
            let instance = self.instance {
                uid = namespace + instance
        }
        
        super.init(signalStrength: signalStrength, identifier: identifier)
    }
    
}
