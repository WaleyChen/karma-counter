//
//  Singleton.m
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-05-11.
//
//

#import "AppDelegate.h"
#import "Singleton.h"

@implementation Singleton

// retreive the entity object
+ (NSObject*)executeFetchRequest:(NSString*)entityName {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:entityName
                                                      inManagedObjectContext:[AppDelegate sharedManagedObjectContext]];
    
    [fetchRequest setEntity:entityDescription];
    
    NSError* error;
    NSArray *fetchedRecords = [[AppDelegate sharedManagedObjectContext] executeFetchRequest:fetchRequest
                                                                                      error:&error];
    
    if ([fetchedRecords count] > 1)
        NSLog(@"More than 1 record fetched for %@", entityName);
    else if ([fetchedRecords count] == 0)
        return nil;
    
    return fetchedRecords[0];
}

// retrives the attribute value from the specified entity
+ (NSObject*)getEntity:(NSString*)entityName attribute:(NSString*)attributeName {
    SEL selector = NSSelectorFromString(attributeName);
    return [[self executeFetchRequest:entityName] performSelector:selector];
}

// set the singleton's attribute value
+ (void)setEntity:(NSString*)entityName attributeName:(NSString*)attributeName attributeValue:(NSObject*)attributeValue {
    NSObject* entity;
    
    // create the entity if it hasn't been created
    if ([self executeFetchRequest:entityName] == nil)
        entity = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                               inManagedObjectContext:[AppDelegate sharedManagedObjectContext]];
    else // otherwise fetch the entity stored
        entity = [self executeFetchRequest:entityName];
 
    [entity setValue:attributeValue forKey:attributeName];
    
    NSError *error;
    
    if (![[AppDelegate sharedManagedObjectContext] save:&error])
        NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
}

@end
