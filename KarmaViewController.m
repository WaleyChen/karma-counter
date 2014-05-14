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
#import "UIView+Toast.h"

@interface KarmaViewController () <CBCentralManagerDelegate, CBPeripheralManagerDelegate, UITableViewDataSource, UITableViewDelegate>

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

@end

@implementation KarmaViewController

#pragma mark - generic

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
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
    
    // observers for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:@"applicationDidEnterBackground"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:@"applicationWillEnterForeground"
                                               object:nil];
}

#pragma mark - notfication handling

- (void)applicationDidEnterBackground {
    NSLog(@"applicationDidEnterBackground");
    [self disconnectAndRemoveAllPeripherals];
}

- (void)applicationWillEnterForeground {
    NSLog(@"applicationWillEnterForeground");
}

#pragma mark - tasks

// this task is responsible for detecting when other KarmaCounters/peripherals are no longer in bluetooth range
// peripherals are no longer in range when the last time we've seen the peripharal is >= 1 second

// note that peripherals broadcast at about 50 times/second and
// when we receive a broadcast from another KarmaCounter didDiscoverPeripheral() is called and
// didDiscoverPeripheral() updates the time we last received a broadcast from the peripheral
- (void)startRemoveExpiredPeripheralsTask {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSDate* lastSeen;
            NSTimeInterval secondsBetween;
            
            pthread_mutex_lock(&_discoveredPeripheralsMutex);
            
                for (int i = 0; i < [_discoveredPeripherals count]; i++) {
                    lastSeen = [_discoveredPeripherals[i] lastSeen];
                    secondsBetween = [[NSDate date] timeIntervalSinceDate:lastSeen];
                
                    if (secondsBetween >= 1) {
                        NSLog(@"Deleted %@", [_discoveredPeripherals[i] nickname]);
                        
                        [self disconnectPeripheral:[_discoveredPeripherals[i] peripheral]];
                        
                        [_discoveredPeripherals removeObjectAtIndex:i];
                        
                        i--;
                    }
                }
            
            pthread_mutex_unlock(&_discoveredPeripheralsMutex);
            
            sleep(1); // sleep in order to not hog the CPU, this decreases the CPU usage from ~100% to ~5%
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_karmaTableView reloadData];
                [self startRemoveExpiredPeripheralsTask];
            });
        });
}


#pragma mark - karmaTableView Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_discoveredPeripherals count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DiscoveredPeripheral* discoveredPeripheral = _discoveredPeripherals[indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"KarmaTableCell" forIndexPath:indexPath];
    cell.textLabel.text = discoveredPeripheral.nickname;
    
    // render the "Send Karma" button if we're able to send karma
    // we're able to send karma when the peripheral has a central object to send karma to
    if (discoveredPeripheral.central != nil) {
        UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        
        sendBtn.frame = CGRectMake(0, 0, 85, 42);
        [sendBtn setTitle:@"Send Karma" forState:UIControlStateNormal];
        sendBtn.highlighted = true;
        [sendBtn addTarget:self action:@selector(sendKarmaBtnPressed:) forControlEvents:UIControlEventTouchUpInside];
    
        cell.accessoryView = sendBtn;
    }
        
    return cell;
}

- (void) sendKarmaBtnPressed:(UIButton *)paramSender {
    UITableViewCell *cell = (UITableViewCell*) paramSender.superview.superview;
    NSString* nicknameOfReceiver = cell.textLabel.text;
    
    DiscoveredPeripheral* discoveredPeripheral = [self findDiscoveredPeripheralWithNickname :nicknameOfReceiver];
    
    if (discoveredPeripheral == nil) {
        NSLog(@"Failure: Could not find %@ in order to send karma", nicknameOfReceiver);
        return;
    }
    
    NSLog(@"To send %@ karma to %@", discoveredPeripheral.karmaToSend, nicknameOfReceiver);
    [self sendKarma:discoveredPeripheral.central karma:[NSNumber numberWithInt:1]];
}

#pragma mark - CBCentralManagerDelegate Methods

/** centralManagerDidUpdateState is a required protocol method.
 *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
 *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
 *  the Central is ready to be used.
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // In a real app, you'd deal with all the states correctly
    if (central.state != CBCentralManagerStatePoweredOn)
        return;
    
    // The state must be CBCentralManagerStatePoweredOn so start scanning
    [self scan];
}

/** Scan for peripherals - specifically for our service's 128bit CBUUID
 */
- (void)scan {
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]
                                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    NSLog(@"Scanning started");
}

/** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
 *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
 *  we start the connection process
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    // Reject any where the value is above reasonable range or is too low to be close enough (Close is around -22dB)
    if (!(-45 <= RSSI.integerValue && RSSI.integerValue <= -15))
        return;
    
    NSDate* curDate = [NSDate date];
    NSString* peripheralNickname = advertisementData[@"kCBAdvDataLocalName"];
    
    DiscoveredPeripheral* discoveredPeripheral = [self findCorrespondingDiscoveredPeripheral:peripheral];
    
    if (discoveredPeripheral == nil) {
        NSLog(@"Discovered peripheral %@", peripheralNickname);
            
        discoveredPeripheral = [[DiscoveredPeripheral alloc] init];
        discoveredPeripheral.karmaToSend = [NSNumber numberWithInt:0];
        discoveredPeripheral.lastSeen = curDate;
        discoveredPeripheral.nickname = peripheralNickname;
        discoveredPeripheral.peripheral = peripheral;
        discoveredPeripheral.UUID = peripheral.identifier.UUIDString;
            
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
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    
    [self deleteDiscoveredPeripheralWithUUID:peripheral.identifier.UUIDString];
}

/** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connection established.");
    NSLog(@"Peripheral Connected");

    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    
    // Search only for services that match our UUID
    [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];
}

/** Once the disconnection happens, we need to clean up our local copy of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Peripheral Disconnected");
    
    [self deleteDiscoveredPeripheralWithUUID:peripheral.identifier.UUIDString];
}

#pragma mark - Peripheral Methods

- (void)disconnectAndRemoveAllPeripherals {
    pthread_mutex_lock(&_discoveredPeripheralsMutex);
    
        for (DiscoveredPeripheral* discoveredPeripheral in _discoveredPeripherals)
            [self disconnectPeripheral:discoveredPeripheral.peripheral];
    
        [_discoveredPeripherals removeAllObjects];
    
    pthread_mutex_unlock(&_discoveredPeripheralsMutex);
    
    [_karmaTableView reloadData];
}

- (void)disconnectPeripheral:(CBPeripheral *)peripheral {
    DiscoveredPeripheral *discoveredPeripheral = [self findCorrespondingDiscoveredPeripheral:peripheral];
    
    if (discoveredPeripheral != nil && discoveredPeripheral.subscribedCharacteristic != nil)
        [peripheral setNotifyValue:NO forCharacteristic:discoveredPeripheral.subscribedCharacteristic];
    
    if (peripheral != nil)
        [self.centralManager cancelPeripheralConnection:peripheral];
}

// Required protocol method.  A full app should take care of all the possible states,
// but we're just waiting for to know when the CBPeripheralManager is ready
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
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
    
    NSLog(@"Exit peripheralManagerDidUpdateState().");
}

/** Catch when someone subscribes to our characteristic
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    NSString* centralUUID = [central identifier].UUIDString;
    
    NSLog(@"Central with UUID of %@ subscribed to characteristic", centralUUID);
    
    DiscoveredPeripheral* discoveredPeripheral = [self findDiscoveredPeripheralWithUUID :centralUUID];
    
    if (discoveredPeripheral == nil) {
        NSLog(@"Could not find peripheral with the UUID %@", centralUUID);
        return;
    }
    
    discoveredPeripheral.central = central;
    [_karmaTableView reloadData];
}

- (BOOL)updateValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)characteristic onSubscribedCentrals:(NSArray *)centrals {
    return YES;
}

/** Recognise when the central unsubscribes
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    NSLog(@"Central %@ unsubscribed from characteristic", [central identifier]);
}

/** Sends the next amount of data to the connected central
 */
- (void)sendKarma:(CBCentral*)central karma:(NSNumber*)karma {
    if (central == nil) {
        NSLog(@"");
        NSLog(@"karma not sent since central is nil");
                
        return;
    }
    
    NSData *dataToSend = [[karma stringValue] dataUsingEncoding:NSUTF8StringEncoding];
    
    // send the karma
    [self.peripheralManager updateValue:dataToSend
                      forCharacteristic:_transferCharacteristic
                   onSubscribedCentrals:[NSArray arrayWithObject:central]];
}

/** This callback comes in when the PeripheralManager is ready to send the next chunk of data.
 *  This is to ensure that packets will arrive in the order they are sent
 */
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral {
    NSLog(@"peripheralManagerIsReadyToUpdateSubscribers()");
}

/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self disconnectPeripheral:peripheral];
        return;
    }
    
    // Discover the characteristic we want...
    
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services)
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]] forService:service];
}


/** The Transfer characteristic was discovered.
 *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    NSLog(@"didDiscoverCharacteristicsForService() START");
    
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self disconnectPeripheral:peripheral];
        return;
    }
    
    DiscoveredPeripheral *discoveredPeripheral = [self findCorrespondingDiscoveredPeripheral:peripheral];
    
    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
            
            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            
            if (discoveredPeripheral == nil)
                NSLog(@"discoveredPeripheral not set");
            else
                discoveredPeripheral.subscribedCharacteristic = characteristic;
        }
    }
    
    // Once this is complete, we just need to wait for the data to come in.
}


/** This callback lets us know more data has arrived via notification on the characteristic
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSNumber *receievedKarma = @([stringFromData intValue]);
    
    [Karma add:receievedKarma];
    [self updateKarmaLabel];
    
    DiscoveredPeripheral *discoveredPeripheral = [self findDiscoveredPeripheralWithUUID:peripheral.identifier.UUIDString];
    NSString *msg = [NSString stringWithFormat:@"%@ sent karma!", discoveredPeripheral.nickname];
    
    [self.view makeToast:msg
                duration:0.5
                position:@"center"];
    
    NSLog(@"Received: %@", stringFromData);
}


/** The peripheral letting us know whether our subscribe/unsubscribe happened or not
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error)
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    
    // Exit if it's not the transfer characteristic
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]])
        return;
    
    // Notification has started
    if (characteristic.isNotifying)
        NSLog(@"Notification began on %@", characteristic);

    // Notification has stopped
    else {
        // so disconnect from the peripheral
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

#pragma mark - _discoveredPeripherals helper methods
- (void) deleteDiscoveredPeripheralWithUUID:(NSString *)str {
    DiscoveredPeripheral* discoveredPeripheral = [self findDiscoveredPeripheralWithString :@"UUID" :str];
    [self disconnectPeripheral:discoveredPeripheral.peripheral];
    [_discoveredPeripherals removeObject:discoveredPeripheral];
}

- (DiscoveredPeripheral*) findCorrespondingDiscoveredPeripheral:(CBPeripheral *)correspondingPeripheral {
    return [self findDiscoveredPeripheralWithUUID:correspondingPeripheral.identifier.UUIDString];
}

- (DiscoveredPeripheral*) findDiscoveredPeripheralWithNickname:(NSString *)str {
    return [self findDiscoveredPeripheralWithString :@"nickname" :str];
}

- (DiscoveredPeripheral*) findDiscoveredPeripheralWithUUID:(NSString *)str {
    return [self findDiscoveredPeripheralWithString :@"UUID" :str];
}

- (DiscoveredPeripheral*) findDiscoveredPeripheralWithString:(NSString *)var :(NSString *)str {
    SEL selector = NSSelectorFromString(var);
    
    pthread_mutex_lock(&_discoveredPeripheralsMutex);
    
        for (DiscoveredPeripheral* discoveredPeripheral in _discoveredPeripherals) {
            if ([(NSString*)[discoveredPeripheral performSelector:selector] isEqualToString:str]) {
                return discoveredPeripheral;
            }
        }
    
        NSLog(@"Could not find _discoveredPeripheral with %@ equals to %@", var, str);
    
//        if ([var isEqualToString:@"UUID"]) {
//            for (DiscoveredPeripheral* discoveredPeripheral in _discoveredPeripherals) {
//                NSLog((NSString*)[discoveredPeripheral performSelector:selector]);
//            }
//        }
    
    pthread_mutex_unlock(&_discoveredPeripheralsMutex);
    
    return nil;
}

#pragma - helper methods

- (void) updateKarmaLabel {
    _karmaLabel.text = [NSString stringWithFormat:@"%d", [[Karma karma] intValue]];
}

@end
