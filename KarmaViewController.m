//
//  KarmaViewController.m
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-05-01.
//
//

#import <CoreBluetooth/CoreBluetooth.h>
#include <pthread.h>

#import "DiscoveredPeripheral.h"
#import "Nickname.h"
#import "Karma.h"
#import "KarmaViewController.h"
#import "TransferService.h"

@interface KarmaViewController () <CBCentralManagerDelegate, CBPeripheralManagerDelegate, UITableViewDataSource, UITableViewDelegate>

// TODO - handle unsent karma
// TODO - reorganize variables
// TODO - closing and reopening the app causes a chrash
// If the user clicks Send Karma, you tell the device belonging to that user to increment their Karma Count.
// If you receive a notification to increment your Karma, you display a dialog indicating who sent you the Karma (using local notifications if the application is in the background).

// central related
@property (strong, nonatomic) CBCentralManager          *centralManager;
@property (strong, nonatomic) NSArray                   *centralsToResendDataTo;

// IBOutlets
@property (weak, nonatomic) IBOutlet UILabel            *karmaLabel;
@property (weak, nonatomic) IBOutlet UITableView        *karmaTableView;
@property (weak, nonatomic) IBOutlet UILabel            *nicknameLabel;

// peripheral related
@property (strong, atomic) NSMutableArray               *discoveredPeripherals;
@property pthread_mutex_t                                discoveredPeripheralsMutex;
@property (strong, nonatomic) CBPeripheralManager       *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic   *transferCharacteristic;

// other
@property (strong, nonatomic) NSTimer                   *sendTimer;
@property (nonatomic, readwrite) NSInteger              sendDataIndex;

// BK - I cache this characteristic so that if you tap the Disconnect Button, we have some mechanism of telling the peripheral.
@property (strong, nonatomic) NSMutableData         *data;

@property (nonatomic, readwrite) NSNumber* num;

@end

#define kSendDataInterval   0.25  // BK - Let's send data every second when connected
#define NOTIFY_MTU          20 // BK - Apple set this to 20, the maximum payload size.

@implementation KarmaViewController

#pragma mark - generic

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
    
    // bluetooth connection related
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    _discoveredPeripherals = [[NSMutableArray alloc] init];
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    
    [self startRemoveExpiredPeripheralsTask];
    
    // view related
    [self updateKarmaLabel];
    _karmaTableView.dataSource = self;
    _karmaTableView.delegate = self;
    _nicknameLabel.text = [NSString stringWithFormat:@"%@%@", [Nickname nickname], @"'s Karma"];
    [self updateKarmaLabel];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:@"applicationDidEnterBackground"
                                               object:nil];
    
    _num = [NSNumber numberWithInt:0];
    
}

- (void)applicationDidEnterBackground
{
    NSLog(@"applicationDidEnterBackground");
    [_discoveredPeripherals removeAllObjects];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - tasks

- (void)startRemoveExpiredPeripheralsTask
{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSDate* lastSeen;
            NSTimeInterval secondsBetween;
            
            pthread_mutex_lock(&_discoveredPeripheralsMutex);
            
                for (int i = 0; i < [_discoveredPeripherals count]; i++)
                {
                    lastSeen = [_discoveredPeripherals[i] lastSeen];
                    secondsBetween = [[NSDate date] timeIntervalSinceDate:lastSeen];
                
                    if (secondsBetween >= 1) {
                        NSLog(@"Deleted %@", [_discoveredPeripherals[i] nickname]);
                        
                        [_discoveredPeripherals removeObjectAtIndex:i];
                        i--;
                    }
                }
            
            pthread_mutex_unlock(&_discoveredPeripheralsMutex);
            
            sleep(1); // decrease CPU usage from ~100% to ~5%
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_karmaTableView reloadData];
                [self startRemoveExpiredPeripheralsTask];
            });
        });
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
    DiscoveredPeripheral* discoveredPeripheral = _discoveredPeripherals[indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"KarmaTableCell" forIndexPath:indexPath];
    cell.textLabel.text = discoveredPeripheral.nickname;
    
    // render the "Send Karma" button if the peripheral has a central object to send karma to
    if (discoveredPeripheral.central != nil) {
        UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        sendBtn.frame = CGRectMake(0, 0, 85, 42);
        [sendBtn setTitle:@"Send Karma" forState:UIControlStateNormal];
        sendBtn.highlighted = true;
        [sendBtn addTarget:self action:@selector(sendKarmaBtnPressed:) forControlEvents:UIControlEventTouchUpInside];
    
        cell.accessoryView = sendBtn;
    } else { // else render please wait
        
    }
        
    return cell;
}

- (void) sendKarmaBtnPressed:(UIButton *)paramSender {
    UITableViewCell *cell = (UITableViewCell*) paramSender.superview.superview;
    NSString* nicknameOfReceiver = cell.textLabel.text;
    
    DiscoveredPeripheral* discoveredPeripheral = [self findDiscoveredPeripheralWithNickname :nicknameOfReceiver];
    
    if (discoveredPeripheral == nil) {
        NSLog(@"Could not find %@ in order to send karma", nicknameOfReceiver);
        return;
    }
    
    NSLog(@"To send %@ karma to %@", discoveredPeripheral.karmaToSend, nicknameOfReceiver);
    discoveredPeripheral.karmaToSend = [NSNumber numberWithInt:([discoveredPeripheral.karmaToSend intValue] +  1)];
    
    [self sendKarma:discoveredPeripheral.central karma:discoveredPeripheral.karmaToSend];
    
    discoveredPeripheral.karmaToSend = [NSNumber numberWithInt:([discoveredPeripheral.karmaToSend intValue] -  1)];
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

/** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
 *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
 *  we start the connection process
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    // Reject any where the value is above reasonable range or is too low to be close enough (Close is around -22dB)
    if (!(-45 <= RSSI.integerValue && RSSI.integerValue <= -15))
        return;
    
    NSDate* curDate = [NSDate date];
    NSString* peripheralNickname = advertisementData[@"kCBAdvDataLocalName"];
    NSString* peripheralUUID = peripheral.identifier.UUIDString;
    
    DiscoveredPeripheral* discoveredPeripheral = [self findDiscoveredPeripheralWithUUID :peripheralUUID];
    
    if (discoveredPeripheral == nil) {
        NSLog(@"Discovered peripheral %@", peripheralNickname);
            
        discoveredPeripheral = [[DiscoveredPeripheral alloc] init];
        discoveredPeripheral.karmaToSend = [NSNumber numberWithInt:0];
        discoveredPeripheral.lastSeen = curDate;
        discoveredPeripheral.nickname = peripheralNickname;
        discoveredPeripheral.peripheral = peripheral;
        discoveredPeripheral.UUID = peripheralUUID;
            
        [_discoveredPeripherals addObject:discoveredPeripheral];
        
        NSLog(@"Connecting to peripheral %@", peripheral);
        [self.centralManager connectPeripheral:peripheral options:nil];
        
        [_karmaTableView reloadData];
    } else {
        discoveredPeripheral.lastSeen = curDate;
    }
}

/** If the connection fails for whatever reason, we need to deal with it.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    
    // set connection state of discovered peripheral
    // have the row cell say "connection failed"
    
    [self cleanup :peripheral];
    
    [self scan]; // restart the connection process
}

/** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Connection established.");
    NSLog(@"Peripheral Connected");
        
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
    [self deleteDiscoveredPeripheralWithUUID :peripheral.identifier.UUIDString];
    
    // We're disconnected, so start scanning again
    [self scan];
}

#pragma mark - Peripheral Methods

// Required protocol method.  A full app should take care of all the possible states,
// but we're just waiting for to know when the CBPeripheralManager is ready
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
    // max number of characters for CBAdvertisementDataLocalNameKey is 29
    [_peripheralManager startAdvertising:@{
        CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]],
           CBAdvertisementDataLocalNameKey:[Nickname nickname]
    }];
    
//    [self.peripheralManager stopAdvertising];
    
    NSLog(@"Exit peripheralManagerDidUpdateState().");
}

/** Catch when someone subscribes to our characteristic
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSString* centralUUID = [central identifier].UUIDString;
    
    NSLog(@"Central with UUID of %@ subscribed to characteristic", centralUUID);
    
    DiscoveredPeripheral* discoveredPeripheral = [self findDiscoveredPeripheralWithUUID :centralUUID];
    
    if (discoveredPeripheral == nil) {
        NSLog(@"Could not find peripheral with the UUID %@", centralUUID);
        return;
    }
    discoveredPeripheral.central = central;
    [_karmaTableView reloadData];
    
    NSString* karmaToSend = [NSString stringWithFormat:@"%d", discoveredPeripheral.karmaToSend.intValue];
    discoveredPeripheral.karmaToSend = [NSNumber numberWithInt:0];
    
    // Reset the index
    self.sendDataIndex = 0;
    
    // Start sending
    [self sendKarma:central karma:discoveredPeripheral.karmaToSend];
}

- (BOOL)updateValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)characteristic onSubscribedCentrals:(NSArray *)centrals
{
    
    
    return YES;
}

/** Recognise when the central unsubscribes
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central %@ unsubscribed from characteristic", [central identifier]);
    
    // BK - Update our battery label to show we have no connection
//    [self.batteryLabel setText:@"Waiting for Connection"];
    
    // BK - Kill our timer
    [self.sendTimer invalidate];
    self.sendTimer =  nil;
    
}

// BK - I added this method for sending timed data
- (void)transferDataBasedOnTimer:(NSTimer *)aTimer {
    
    // BK - tee it up.
    
    // Reset the index
    self.sendDataIndex = 0;
    
    // Start sending
//    [self sendData];
    
    // Do it all over again.
    [self.sendTimer invalidate];
    self.sendTimer = nil;
//    self.sendTimer = [NSTimer scheduledTimerWithTimeInterval:kSendDataInterval target:self selector:@selector(transferDataBasedOnTimer:) userInfo:nil repeats:NO];
}

/** Sends the next amount of data to the connected central
 */
- (void)sendKarma:(CBCentral*)central karma:(NSNumber*)karma
{
    if (central == nil) {
        NSLog(@"Data not sent, central is nil");
    }
    
    NSString *karmaString = [karma stringValue];
    NSData *dataToSend = [karmaString dataUsingEncoding:NSUTF8StringEncoding];
    
    // First up, check if we're meant to be sending an EOM
    static BOOL sendingEOM = NO;
    
    if (sendingEOM) {
        
        // send it
        BOOL didSend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding]
                                         forCharacteristic:self.transferCharacteristic
                                      onSubscribedCentrals:[NSArray arrayWithObject:central]];
        
        // Did it send?
        if (didSend) {
            
            // It did, so mark it as sent
            sendingEOM = NO;
            
            NSLog(@"Sent: EOM");
        }
        
//        centralsToResendDataTo = centrals;
        
        // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    
    // There's data left, so send until the callback fails, or we're done.
    
    BOOL didSend = YES;
    
    while (didSend) {
        
        // Copy out the data we want
        NSData *chunk = dataToSend;
        
        if (_peripheralManager == nil) {
            NSLog(@"peripheralManager is nil.");
            return;
        }
        
        if (chunk == nil) {
            NSLog(@"chunk is nil.");
            return;
        }
        
        if (central == nil) {
            NSLog(@"central is nil.");
            return;
        }
        
        // Send it
        didSend = [self.peripheralManager updateValue:chunk
                                    forCharacteristic:_transferCharacteristic
                                 onSubscribedCentrals:[NSArray arrayWithObject:central]];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSend) {
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent: %@", stringFromData);
    }
}

/** This callback comes in when the PeripheralManager is ready to send the next chunk of data.
 *  This is to ensure that packets will arrive in the order they are sent
 */
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    NSLog(@"peripheralManagerIsReadyToUpdateSubscribers()");
    
    // Start sending again
//    [self sendData _centralsToResendDataTo];
}

/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanup :peripheral];
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
    NSLog(@"didDiscoverCharacteristicsForService() START");
    
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanup :peripheral];
        return;
    }
    
    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
            
            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
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
        return;
    }
    
    NSNumber *receievedKarma = @([stringFromData intValue]);
    [Karma add:receievedKarma];
    [self updateKarmaLabel];
    
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
- (void)cleanup :(CBPeripheral *)peripheral
{
    // Don't do anything if we're not connected
    if (!peripheral.isConnected) {
        return;
    }
    
    NSLog(@"Cleanup()");
    
    // See if we are subscribed to a characteristic on the peripheral
    if (peripheral.services != nil) {
        for (CBService *service in peripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            // It is notifying, so unsubscribe
                            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
                            
                            // And we're done.
                            return;
                        }
                    }
                }
            }
        }
    }
    
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:peripheral];
}

#pragma mark - _discoveredPeripherals helper methods

- (void) deleteDiscoveredPeripheralWithUUID :(NSString *)str {
    DiscoveredPeripheral* discoveredPeripheral = [self findDiscoveredPeripheralWithString :@"UUID" :str];
    [_discoveredPeripherals removeObject:discoveredPeripheral];
}

- (DiscoveredPeripheral*) findDiscoveredPeripheralWithNickname :(NSString *)str {
    return [self findDiscoveredPeripheralWithString :@"nickname" :str];
}

- (DiscoveredPeripheral*) findDiscoveredPeripheralWithUUID :(NSString *)str {
    return [self findDiscoveredPeripheralWithString :@"UUID" :str];
}

- (DiscoveredPeripheral*) findDiscoveredPeripheralWithString :(NSString *)var :(NSString *)str {
    SEL selector = NSSelectorFromString(var);
    
    pthread_mutex_lock(&_discoveredPeripheralsMutex);
    
        for (DiscoveredPeripheral* discoveredPeripheral in _discoveredPeripherals) {
            if ([(NSString*)[discoveredPeripheral performSelector:selector] isEqualToString:str]) {
                return discoveredPeripheral;
            }
        }
    
    NSLog(@"Could not find _discoveredPeripheral with %@ equals to %@", var, str);
    
    if ([var isEqualToString:@"UUID"]) {
        for (DiscoveredPeripheral* discoveredPeripheral in _discoveredPeripherals) {
            NSLog((NSString*)[discoveredPeripheral performSelector:selector]);
        }
    }
    
    pthread_mutex_unlock(&_discoveredPeripheralsMutex);
    
    return nil;
}

#pragma - helper methods

- (void) updateKarmaLabel {
    _karmaLabel.text = [NSString stringWithFormat:@"%d", [[Karma karma] intValue]];
}

@end
