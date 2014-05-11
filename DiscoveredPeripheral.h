//
//  DiscoveredPeripheral.h
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-05-10.
//
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>

@interface DiscoveredPeripheral : NSObject

@property (atomic, readwrite) CBCentral     *central;
@property (atomic, readwrite) NSNumber      *karmaToSend;
@property (atomic, readwrite) NSDate        *lastSeen;
@property (atomic, readwrite) NSString      *nickname;
@property (atomic, readwrite) CBPeripheral  *peripheral;
@property (atomic, readwrite) NSString      *UUID;

@end
