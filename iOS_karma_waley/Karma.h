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

+ (NSNumber*)getKarma;
+ (void)addKarma:(NSNumber *)karmaToAdd;

@end
