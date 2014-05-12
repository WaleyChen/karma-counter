//
//  Karma.m
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-05-01.
//
//

#import "AppDelegate.h"
#import "Karma.h"
#import "Singleton.h"

@implementation Karma

@dynamic karma;

+ (void)add:(NSNumber *)karma {
    karma = [NSNumber numberWithInt:([[self karma] intValue] + [karma intValue])];
    [Singleton setEntity:@"Karma" attributeName:@"karma" attributeValue:karma];
}

+ (NSNumber*)karma {
    return (NSNumber*)[Singleton getEntity:@"Karma" attribute:@"karma"];
}

+ (void)setKarma:(NSNumber *)karma {
    [Singleton setEntity:@"Karma" attributeName:@"karma" attributeValue:karma];
}

@end
