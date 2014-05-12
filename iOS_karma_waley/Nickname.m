//
//  Nickname.m
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-04-30.
//
//

#import "AppDelegate.h"
#import "Nickname.h"
#import "Singleton.h"

@implementation Nickname

@dynamic nickname;

+ (NSString*)nickname {
    return (NSString*)[Singleton getEntity:@"Nickname" attribute:@"nickname"];
}

+ (void)setNickname:(NSString *)nickname {
    [Singleton setEntity:@"Nickname" attributeName:@"nickname" attributeValue:nickname];
}

@end
