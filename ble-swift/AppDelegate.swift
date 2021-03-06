//
//  AppDelegate.swift
//  ble-swift
//
//  Created by Yuan on 14-10-20.
//  Copyright (c) 2014年 xuyuanme. All rights reserved.
//

import UIKit
import CoreLocation
import Parse
import CoreBluetooth

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate, UIAlertViewDelegate, CreatePeripheralProtocol, ConnectPeripheralProtocol, ReadPeripheralProtocol {

    var window: UIWindow?
    var locationManager: CLLocationManager!
    
    var serviceUUIDString:String = ""
    var characteristicUUIDString:String = ""
    
    var discoveredPeripherals : Dictionary<CBPeripheral, Peripheral> = [:]

    // MARK: UIApplicationDelegate
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        if (application.respondsToSelector(Selector("registerUserNotificationSettings:"))) {
            application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: UIUserNotificationType.Sound | UIUserNotificationType.Alert |
                UIUserNotificationType.Badge, categories: nil))
            application.registerForRemoteNotifications()
        } else {
            application.registerForRemoteNotificationTypes(UIRemoteNotificationType.Badge | UIRemoteNotificationType.Sound | UIRemoteNotificationType.Alert)
        }
        
        if var options = launchOptions {
            if var localNotification: UILocalNotification = options[UIApplicationLaunchOptionsLocalNotificationKey] as? UILocalNotification {
                // User click local notification to launch app
                // Need to handle the local notification here
                Utils.showAlert("didFinishLaunchingWithOptions \(localNotification.alertBody!)")
            }
            if var remoteNotification: NSDictionary = options[UIApplicationLaunchOptionsRemoteNotificationKey] as? NSDictionary {
                // Awake from remote notification
                // No further logic here, will be handled by application didReceiveRemoteNotification fetchCompletionHandler
                Utils.sendNotification("Awake from remote notification", soundName: "")
            }
            if var booleanFlag: NSNumber = options[UIApplicationLaunchOptionsLocationKey] as? NSNumber {
                // Awake from location
                // No further logic here, will be handled by locationManager didUpdateLocations
                Utils.sendNotification("Awake from location", soundName: "")
            }
            if var centralManagerIdentifiers: NSArray = options[UIApplicationLaunchOptionsBluetoothCentralsKey] as? NSArray {
                // Awake as Bluetooth Central
                // No further logic here, will be handled by centralManager willRestoreState
                Utils.sendNotification("Awake as Bluetooth Central", soundName: "")
            }
            if var peripheralManagerIdentifiers: NSArray = options[UIApplicationLaunchOptionsBluetoothPeripheralsKey] as? NSArray {
                // Awake as Bluetooth Peripheral
                // No further logic here, will be handled by peripheralManager willRestoreState
                Utils.sendNotification("Awake as Bluetooth Peripheral", soundName: "")
            }
        }

        // Initialize the Location Manager
        initLocationManager()
        
        initParse()
        
        initBluetooth()

        return true
    }
    
    func initLocationManager() {
        if (nil == locationManager) {
            Logger.debug("Initialize Location Manager")
            locationManager = CLLocationManager()
        }
        locationManager.delegate = self
        if (locationManager.respondsToSelector(Selector("requestAlwaysAuthorization"))) {
            Logger.debug("requestAlwaysAuthorization for iOS8")
            
            var status:CLAuthorizationStatus = CLLocationManager.authorizationStatus()
            
            if (status == CLAuthorizationStatus.Denied || status == CLAuthorizationStatus.AuthorizedWhenInUse) {
                var alert = UIAlertView(title: status == CLAuthorizationStatus.Denied ? "Location services are off" : "Background location is not enabled", message: "To use background location you must turn on 'Always' in the Location Services Settings", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "Settings")
                alert.show()
            } else if (status == CLAuthorizationStatus.NotDetermined) {
                locationManager.requestAlwaysAuthorization()
            }
        }
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    func initParse() {
        var myDict: NSDictionary?
        if let path = NSBundle.mainBundle().pathForResource("Keys", ofType: "plist") {
            myDict = NSDictionary(contentsOfFile: path)
        }
        if let dict = myDict {
            Parse.setApplicationId(dict["ApplicationId"] as String, clientKey: dict["ClientKey"] as String)
        }
    }
    
    func initBluetooth() {
        var myDict: NSDictionary?
        if let path = NSBundle.mainBundle().pathForResource("Keys", ofType: "plist") {
            myDict = NSDictionary(contentsOfFile: path)
        }
        if let dict = myDict {
            self.serviceUUIDString = dict["ServiceUUIDString"] as String
            self.characteristicUUIDString = dict["NameCharacteristicUUIDString"] as String
        }
        
        CentralManager.sharedInstance().connectPeripheralDelegate = self
        PeripheralManager.sharedInstance().createPeripheralDelegate = self
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        var characterSet: NSCharacterSet = NSCharacterSet(charactersInString: "<>")
        var deviceTokenString: String = (deviceToken.description as NSString)
            .stringByTrimmingCharactersInSet( characterSet)
            .stringByReplacingOccurrencesOfString(" ", withString: "") as String
        
        Logger.debug("didRegisterForRemoteNotificationsWithDeviceToken \(deviceTokenString)")
        
        var currentInstallation = PFInstallation.currentInstallation()
        currentInstallation.setDeviceTokenFromData(deviceToken)
        if(PFUser.currentUser() != nil) {
            currentInstallation["user"] = PFUser.currentUser()
        }
        PFGeoPoint.geoPointForCurrentLocationInBackground { (geoPoint:PFGeoPoint!, error:NSError!) -> Void in
            if(error == nil) {
                currentInstallation["location"] = geoPoint
            } else {
                Logger.debug("Get user location error: \(error)")
            }
            currentInstallation.saveInBackgroundWithBlock(nil)
        }
    }
    
    func application(application: UIApplication!, didFailToRegisterForRemoteNotificationsWithError error: NSError!) {
        Logger.debug("didFailToRegisterForRemoteNotificationsWithError \(error.localizedDescription)")
    }
    
    func application(application: UIApplication, didReceiveLocalNotification localNotification:UILocalNotification) {
        // Receive local notification in the foreground
        // Or user click local notification to switch to foreground
        Logger.debug("didReceiveLocalNotification "+localNotification.alertBody!)
        // Utils.showAlert("didReceiveLocalNotification \(localNotification.alertBody!)")
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        var notification:NSDictionary = userInfo["aps"] as NSDictionary
        if (application.applicationState == UIApplicationState.Active || application.applicationState == UIApplicationState.Inactive) {
            if let alert = notification.objectForKey("alert") as? String {
                // If the value is Inactive, the user tapped an action button; if the value is Active, the app was frontmost when it received the notification
                Utils.showAlert("didReceiveRemoteNotification \(application.applicationState.rawValue.description) \(alert)")
                application.applicationIconBadgeNumber = 0
            } else {
                // content-available
                Logger.debug(userInfo)
            }
        } else {
            // Background or Not Running
            Logger.debug(userInfo)
        }
        
        if(application.applicationState == UIApplicationState.Inactive) {
            // The application was just brought from the background to the foreground,
            // so we consider the app as having been "opened by a push notification."
            PFAnalytics.trackAppOpenedWithRemoteNotificationPayloadInBackground(userInfo, block: nil);
        }
    }

    // Silent remote notification sample:
    //    {
    //      aps = {
    //          sound = "";
    //          "content-available" = 1;
    //      };
    //      type = rescan;
    //    }
    func application(application: UIApplication!, didReceiveRemoteNotification userInfo:[NSObject : AnyObject], fetchCompletionHandler handler:(UIBackgroundFetchResult) -> Void) {
        if let type = userInfo["type"] as? String {
            if(type == "rescan") {
                Logger.debug("Received silent notification, restart bluetooth scanning")
                CentralManager.sharedInstance().stopScanning()
                CentralManager.sharedInstance().startScanning(afterPeripheralDiscovered, allowDuplicatesKey: false)
            }
        } else {
            self.application(application, didReceiveRemoteNotification: userInfo)
        }
        handler(UIBackgroundFetchResult.NewData)
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    // MARK: CLLocationManagerDelegate
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [CLLocation]!) {
        Logger.debug("Updated locations: \(locations)")
//        Utils.sendNotification("\(locations)", soundName: "")
        var currentInstallation = PFInstallation.currentInstallation()
        currentInstallation["location"] = PFGeoPoint(location: locations[0])
        currentInstallation.saveInBackgroundWithBlock(nil)
    }
    
    // MARK: UIAlertViewDelegate
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if (buttonIndex == 1) {
            var settingURL = NSURL(string: UIApplicationOpenSettingsURLString)
            UIApplication.sharedApplication().openURL(settingURL!)
        }
    }
    
    // MARK: CreatePeripheralProtocol
    func didReceiveReadRequest(peripheralManager: CBPeripheralManager!, didReceiveReadRequest request: CBATTRequest!) {
        if(request.characteristic.UUID.UUIDString == self.characteristicUUIDString) {
            var result = ""
            if let user = PFUser.currentUser() {
                result = user.username + " " + PFInstallation.currentInstallation().objectId
            } else {
                result = "Unknown " + PFInstallation.currentInstallation().objectId
            }
            request.value = NSData(data: result.dataUsingEncoding(NSUTF8StringEncoding)!)
            peripheralManager.respondToRequest(request, withResult: CBATTError.Success)
        }
    }
    
    // MARK: ConnectPeripheralProtocol
    func didConnectPeripheral(cbPeripheral: CBPeripheral!) {
        Logger.debug("AppDelegate#didConnectPeripheral \(cbPeripheral.name)")
        if let peripheral = self.discoveredPeripherals[cbPeripheral] {
            peripheral.discoverServices([CBUUID(string: serviceUUIDString)], delegate: self)
        }
    }
    
    func didDisconnectPeripheral(cbPeripheral: CBPeripheral!, error: NSError!, userClickedCancel: Bool) {
        Logger.debug("AppDelegate#didDisconnectPeripheral \(cbPeripheral.name)")
    }
    
    func didRestorePeripheral(peripheral: Peripheral) {
        Logger.debug("AppDelegate#didRestorePeripheral \(peripheral.name)")
    }
    
    func bluetoothBecomeAvailable() {
        self.startScanning()
    }
    
    func bluetoothBecomeUnavailable() {
        self.stopScanning()
    }
    
    // MARK: ReadPeripheralProtocol
    func didUpdateValueForCharacteristic(cbPeripheral: CBPeripheral!, characteristic: CBCharacteristic!, error: NSError!) {
        if let data = characteristic.value {
            if let result = NSString(data: data, encoding: NSUTF8StringEncoding) {
                Logger.debug("AppDelegate#didUpdateValueForCharacteristic \(result)")
                let results = result.componentsSeparatedByString(" ")
                var username:String = results[0] as String
                var installationId = results[1] as String
                var discoveredDevice = PFInstallation()
                discoveredDevice.objectId = installationId
                self.uploadDiscoveryToParse(PFInstallation.currentInstallation(), discoveredDevice: discoveredDevice)
                
                if let peripheral:Peripheral = discoveredPeripherals[cbPeripheral] {
                    peripheral.name = username
                    peripheral.installationId = installationId
                    peripheral.hasBeenConnected = true
                }

                NSNotificationCenter.defaultCenter().postNotificationName("didUpdateValueForCharacteristic", object: nil)
            }
        } else {
            Logger.debug("AppDelegate#didUpdateValueForCharacteristic: Received nil characteristic value from peripheral \(cbPeripheral.name)")
        }
        if let peripheral = self.discoveredPeripherals[cbPeripheral] {
            Logger.debug("AppDelegate#didUpdateValueForCharacteristic: Cancel peripheral connection")
            CentralManager.sharedInstance().cancelPeripheralConnection(peripheral, userClickedCancel: true);
        }
    }
    
    // MARK: Pbulic functions
    func startScanning() {
        for peripheral:Peripheral in self.discoveredPeripherals.values.array {
            peripheral.isNearby = false
        }
        CentralManager.sharedInstance().startScanning(afterPeripheralDiscovered, allowDuplicatesKey: false)
    }
    
    func stopScanning() {
        CentralManager.sharedInstance().stopScanning()
    }
    
    func afterPeripheralDiscovered(cbPeripheral:CBPeripheral, advertisementData:NSDictionary, RSSI:NSNumber) {
        Logger.debug("AppDelegate#afterPeripheralDiscovered: \(cbPeripheral)")
        var peripheral : Peripheral
        
        if let p = discoveredPeripherals[cbPeripheral] {
            peripheral = p
        } else {
            peripheral = Peripheral(cbPeripheral:cbPeripheral, advertisements:advertisementData, rssi:RSSI.integerValue)
            discoveredPeripherals[peripheral.cbPeripheral] = peripheral
        }
        
        peripheral.isNearby = true

        if (!peripheral.hasBeenConnected) {
            CentralManager.sharedInstance().connectPeripheral(peripheral)
        } else {
            var discoveredDevice = PFInstallation()
            discoveredDevice.objectId = peripheral.installationId
            self.uploadDiscoveryToParse(PFInstallation.currentInstallation(), discoveredDevice: discoveredDevice)
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName("afterPeripheralDiscovered", object: nil)
    }
    
    // MARK: - Private
    private func uploadDiscoveryToParse(fromDevice:PFInstallation, discoveredDevice:PFInstallation) {
        var discovery = PFObject(className: "Discovery")
        discovery["fromDevice"] = fromDevice
        discovery["discoveredDevice"] = discoveredDevice
        PFGeoPoint.geoPointForCurrentLocationInBackground { (geoPoint:PFGeoPoint!, error:NSError!) -> Void in
            if(error == nil) {
                discovery["location"] = geoPoint
            } else {
                Logger.debug("Get user location error: \(error)")
            }
            discovery.saveInBackgroundWithBlock(nil)
        }
    }

}
