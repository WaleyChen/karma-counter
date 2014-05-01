//
//  Nickname.h
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-04-30.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface Nickname : NSManagedObject

@property (nonatomic, retain) NSString * nickname;

+ (NSString*)getNickname;
+ (void)setNickname:(NSString *)nickname;
+ (id)sharedNickname;

@end
