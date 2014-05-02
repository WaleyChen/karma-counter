//
//  KarmaViewController.m
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-05-01.
//
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "Nickname.h"
#import "KarmaViewController.h"
#import "TransferService.h"

@interface KarmaViewController () <CBCentralManagerDelegate, CBPeripheralManagerDelegate, UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) CBCentralManager          *centralManager;
@property (strong, nonatomic) CBPeripheral              *discoveredPeripheral;
@property (strong, nonatomic) NSMutableArray            *discoveredPeripherals;

@property (weak, nonatomic) IBOutlet UILabel            *nicknameLabel;
@property (weak, nonatomic) IBOutlet UITableView        *karmaTableView;

@property (strong, nonatomic) CBPeripheralManager       *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic   *transferCharacteristic;

// BK - added a label to show signal strength
// Note that "RSSI" is the Received Signal Strength Indicator.  To calculate a percentage, you need to know
// how powerful your transmitter is.  I don't believe iOS or Apple tells us that yet on iOS6.
@property (strong, nonatomic) IBOutlet UILabel          *rssiLabel;

@property (strong, nonatomic) NSTimer                   *sendTimer;
@property (strong, nonatomic) NSData                    *dataToSend;
@property (nonatomic, readwrite) NSInteger              sendDataIndex;

// BK - I cache this characteristic so that if you tap the Disconnect Button, we have some mechanism of telling the peripheral.
@property (strong, nonatomic) CBCharacteristic      *subscribedCharacteristic;
@property (strong, nonatomic) NSMutableData         *data;

@property(strong, nonatomic) NSNumber *num;

@end

#define kSendDataInterval   1.0                         // BK - Let's send data every second when connected

// BK - Apple set this to 20, the maximum payload size.
#define NOTIFY_MTU      20

@implementation KarmaViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _discoveredPeripherals = [[NSMutableArray alloc] init];
    _num = [NSNumber numberWithInt:0];
    
    // bluetooth
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    
    // view elements
    _nicknameLabel.text = [NSString stringWithFormat:@"%@%@", [Nickname getNickname], @"'s Karma"];
    
    _karmaTableView.dataSource = self;
    _karmaTableView.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - karmaTableView Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_discoveredPeripherals count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"KarmaTableCell" forIndexPath:indexPath];
    
    cell.textLabel.text = ((NSString*)([_discoveredPeripherals objectAtIndex:indexPath.row]));
    
    return cell;
}

#pragma mark - CBCentralManagerDelegate Methods

/** centralManagerDidUpdateState is a required protocol method.
 *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
 *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
 *  the Central is ready to be used.
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    // In a real app, you'd deal with all the states correctly
    if (central.state != CBCentralManagerStatePoweredOn)
        return;
    
    // The state must be CBCentralManagerStatePoweredOn so start scanning
    [self scan];
}

/** Scan for peripherals - specifically for our service's 128bit CBUUID
 */
- (void)scan
{
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]
                                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    NSLog(@"Scanning started");
}

// BK - This method allows us to force-kill the connection
-(IBAction)disconnectFromPeripheral:(id)sender {
    
    // You should really tell the Peripheral that you don't care anymore.  Otherwise, it will keep trying to transfer data.
    [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:_subscribedCharacteristic];
    
    // Now kill the connection
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}

/** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
 *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
 *  we start the connection process
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    // Reject any where the value is above reasonable range or is too low to be close enough (Close is around -22dB)
    if (!(-45 <= RSSI.integerValue && RSSI.integerValue <= -15))
        return;
    
    NSString* peripheralName = advertisementData[@"kCBAdvDataLocalName"];
    
//    NSLog(@"Discovered peripheral %@", peripheralName);
    
    if (![_discoveredPeripherals containsObject:peripheralName]) {
        NSLog(@"Discovered peripheral %@", peripheralName);
        
        [_discoveredPeripherals addObject:peripheralName];
        [_karmaTableView reloadData];
        
        NSLog(@"Table size %d", [_discoveredPeripherals count]);
    }
    
    return;
    
        // Ok, it's in range - have we already seen it?
        if (self.discoveredPeripheral != peripheral) {
    
            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
            self.discoveredPeripheral = peripheral;
    
            // And connect
            NSLog(@"Connecting to peripheral %@", peripheral);
            [self.centralManager connectPeripheral:peripheral options:nil];
            
            // BK - Update our connection status label.
//            [self.connectionLabel setText:@"Yes"];
//            [self.disconnectButton setEnabled:YES];
//            [self.disconnectButton setAlpha:1.0];
    
        }
}

/** If the connection fails for whatever reason, we need to deal with it.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    [self cleanup];
}

/** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Connection established.");
    NSLog(@"Peripheral Connected");
    
    // Stop scanning
//    [self.centralManager stopScan];
//    NSLog(@"Scanning stopped");
    
    // Clear the data that we may already have
    [self.data setLength:0];
    
    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    
    // Search only for services that match our UUID
    [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];
}

/** Once the disconnection happens, we need to clean up our local copy of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral Disconnected");
    self.discoveredPeripheral = nil;
    
    // We're disconnected, so start scanning again
    [self scan];
    
    // BK - Update our connection status label.
    //    [self.connectionLabel setText:@"No"];
    //    [self.disconnectButton setEnabled:NO];
    //    [self.disconnectButton setAlpha:0.5];
}

#pragma mark - Peripheral Methods



/** Required protocol method.  A full app should take care of all the possible states,
 *  but we're just waiting for to know when the CBPeripheralManager is ready
 */
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    // Opt out from any other state
    if (peripheral.state != CBPeripheralManagerStatePoweredOn)
        return;
    
    // We're in CBPeripheralManagerStatePoweredOn state...
    NSLog(@"self.peripheralManager powered on.");
    
    // ... so build our service.
    
    // Start with the CBMutableCharacteristic
    self.transferCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]
                                                                     properties:CBCharacteristicPropertyNotify
                                                                          value:nil
                                                                    permissions:CBAttributePermissionsReadable];
    
    // Then the service
    CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]
                                                                       primary:YES];
    
    // Add the characteristic to the service
    transferService.characteristics = @[self.transferCharacteristic];
    
    // And add it to the peripheral manager
    [self.peripheralManager addService:transferService];
    
    // BK - since we just want to start advertising right away, let's do that here, after we determine that the peripheralManager is good to go.
    [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]],
                                                CBAdvertisementDataLocalNameKey : [NSString stringWithFormat:@"%@ %@", [Nickname getNickname], _num] }];
    
//    [self.peripheralManager stopAdvertising];
    
    _num = [NSNumber numberWithInt:([_num intValue] + 1)];
    
    NSLog(@"Exit peripheralManagerDidUpdateState().");
}

/** Catch when someone subscribes to our characteristic, then start sending them data
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central subscribed to characteristic");
    NSLog(@"Peripheral stops advertising.");
    [self.peripheralManager stopAdvertising];
    return;
    
    // Get the data
    // BK - Apple used this originally to send text.  We just want to send battery percentage.  I kept the view and just hid it for now.
    //self.dataToSend = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
//    [self.textView setHidden:YES];
    
    // BK - Fire up a timer that will send data at regular intervals.
    self.sendTimer = [NSTimer scheduledTimerWithTimeInterval:kSendDataInterval target:self selector:@selector(transferDataBasedOnTimer:) userInfo:nil repeats:NO];
    
    // BK - Get the battery percentage
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    NSNumber *batteryLevel = [NSNumber numberWithFloat:(100*[[UIDevice currentDevice] batteryLevel])];
    NSString *batteryLevelString = [NSString stringWithFormat:@"%@%%", batteryLevel];
    
    // BK - Show it locally.  I display "Waiting for Connection" until the connection occurs, then update the label.
//    [self.batteryLabel setText:batteryLevelString];
    
    // BK - tee it up.
    self.dataToSend = [batteryLevelString dataUsingEncoding:NSUTF8StringEncoding];
    
    // Reset the index
    self.sendDataIndex = 0;
    
    // Start sending
    [self sendData];
}

/** Recognise when the central unsubscribes
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central unsubscribed from characteristic");
    
    // BK - Update our battery label to show we have no connection
//    [self.batteryLabel setText:@"Waiting for Connection"];
    
    // BK - Kill our timer
    [self.sendTimer invalidate];
    self.sendTimer =  nil;
    
}

// BK - I added this method for sending timed data
- (void)transferDataBasedOnTimer:(NSTimer *)aTimer {
    
    // BK - Get the battery percentage
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    NSNumber *batteryLevel = [NSNumber numberWithFloat:(100*[[UIDevice currentDevice] batteryLevel])];
    NSString *batteryLevelString = [NSString stringWithFormat:@"%@%%", batteryLevel];
    
    // BK - Show it locally.  I display "Waiting for Connection" until the connection occurs, then update the label.
//    [self.batteryLabel setText:batteryLevelString];
    
    // BK - tee it up.
    self.dataToSend = [batteryLevelString dataUsingEncoding:NSUTF8StringEncoding];
    
    // Reset the index
    self.sendDataIndex = 0;
    
    // Start sending
    [self sendData];
    
    // Do it all over again.
    [self.sendTimer invalidate];
    self.sendTimer = nil;
    self.sendTimer = [NSTimer scheduledTimerWithTimeInterval:kSendDataInterval target:self selector:@selector(transferDataBasedOnTimer:) userInfo:nil repeats:NO];
    
}

/** Sends the next amount of data to the connected central
 */
- (void)sendData
{
    // First up, check if we're meant to be sending an EOM
    static BOOL sendingEOM = NO;
    
    if (sendingEOM) {
        
        // send it
        BOOL didSend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
        
        // Did it send?
        if (didSend) {
            
            // It did, so mark it as sent
            sendingEOM = NO;
            
            NSLog(@"Sent: EOM");
        }
        
        // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    
    // We're not sending an EOM, so we're sending data
    
    // Is there any left to send?
    
    if (self.sendDataIndex >= self.dataToSend.length) {
        
        // No data left.  Do nothing
        return;
    }
    
    // There's data left, so send until the callback fails, or we're done.
    
    BOOL didSend = YES;
    
    while (didSend) {
        
        // Make the next chunk
        
        // Work out how big it should be
        NSInteger amountToSend = self.dataToSend.length - self.sendDataIndex;
        
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) amountToSend = NOTIFY_MTU;
        
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.dataToSend.bytes+self.sendDataIndex length:amountToSend];
        
        // Send it
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSend) {
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent: %@", stringFromData);
        
        // It did send, so update our index
        self.sendDataIndex += amountToSend;
        
        // Was it the last one?
        if (self.sendDataIndex >= self.dataToSend.length) {
            
            // It was - send an EOM
            
            // Set this so if the send fails, we'll send it next time
            sendingEOM = YES;
            
            // Send it
            BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
            
            if (eomSent) {
                // It sent, we're all done
                sendingEOM = NO;
                
                NSLog(@"Sent: EOM");
            }
            
            return;
        }
    }
}

/** This callback comes in when the PeripheralManager is ready to send the next chunk of data.
 *  This is to ensure that packets will arrive in the order they are sent
 */
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    // Start sending again
    [self sendData];
}

/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
    
    // Discover the characteristic we want...
    
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]] forService:service];
    }
}


/** The Transfer characteristic was discovered.
 *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
    
    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
            
            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            _subscribedCharacteristic = characteristic;
        }
    }
    
    // Once this is complete, we just need to wait for the data to come in.
}


/** This callback lets us know more data has arrived via notification on the characteristic
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
    // Have we got everything we need?
    if ([stringFromData isEqualToString:@"EOM"]) {
        
        // We have, so show the data,
//        [self.textview setText:[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]];
        
        // Cancel our subscription to the characteristic
        // BK - I took this out.  As long as we're connected, keep feeding me data.
        //[peripheral setNotifyValue:NO forCharacteristic:characteristic];
        
        // and disconnect from the peripehral
        // BK - I took this out.  Once we're connected, let's just stay connected.
        //[self.centralManager cancelPeripheralConnection:peripheral];
    }
    
    // Otherwise, just add the data on to what we already have
//    [self.data appendData:characteristic.value];
    
    // BK - if we want to, we can update the signal strength while connected.  Since
    // I'm no longer advertising, RSSI updates will stop unless I do this.
    [peripheral readRSSI];
    [self.rssiLabel setText:[NSString stringWithFormat:@"%@ dBm", [peripheral RSSI]]];
    
    // Log it
    NSLog(@"Received: %@", stringFromData);
}


/** The peripheral letting us know whether our subscribe/unsubscribe happened or not
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    
    // Exit if it's not the transfer characteristic
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
        return;
    }
    
    // Notification has started
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
    }
    
    // Notification has stopped
    else {
        // so disconnect from the peripheral
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

/** Call this when things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
- (void)cleanup
{
    // Don't do anything if we're not connected
    if (!self.discoveredPeripheral.isConnected) {
        return;
    }
    
    // See if we are subscribed to a characteristic on the peripheral
    if (self.discoveredPeripheral.services != nil) {
        for (CBService *service in self.discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            // It is notifying, so unsubscribe
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            
                            // And we're done.
                            return;
                        }
                    }
                }
            }
        }
    }
    
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}

@end
