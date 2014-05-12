//
//  Singleton.h
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-05-11.
//
//

#import <Foundation/Foundation.h>

@interface Singleton : NSObject

+ (NSObject*)getEntity:(NSString*)entityName attribute:(NSString*)attributeName;
+ (void)setEntity:(NSString*)entityName attributeName:(NSString*)attributeName attributeValue:(NSObject*)attributeValue;

@end
