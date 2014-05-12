//
//  Karma.h
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-05-01.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface Karma : NSManagedObject

@property (nonatomic, retain) NSNumber * karma;

+ (void)add:(NSNumber *)karma;
+ (NSNumber*)karma;
+ (void)setKarma:(NSNumber *)karma;

@end
