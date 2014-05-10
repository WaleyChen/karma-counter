//
//  DiscoveredPeripheral.h
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-05-10.
//
//

#import <Foundation/Foundation.h>

@interface DiscoveredPeripheral : NSObject

@property (atomic, readwrite) NSString  *nickname;
@property (atomic, readwrite) NSDate    *lastSeen;
@property (atomic, readwrite) NSNumber  *karmaToSend;
@property (atomic, readwrite) NSString  *UUID;

@end
