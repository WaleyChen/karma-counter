//
//  Karma.m
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-05-01.
//
//

#import "AppDelegate.h"
#import "Karma.h"


@implementation Karma

@dynamic karma;

+ (NSNumber*)getKarma
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *nicknameEntity = [
        NSEntityDescription entityForName:@"Karma"
        inManagedObjectContext:[AppDelegate sharedManagedObjectContext]
    ];
    [fetchRequest setEntity:nicknameEntity];
    
    NSError* error;
    NSArray *fetchedRecords = [
                               [AppDelegate sharedManagedObjectContext] executeFetchRequest:fetchRequest error:&error
                               ];
    
    if ([fetchedRecords count] == 0)
        return nil;
    
    return ((Karma*)fetchedRecords[0]).karma;
}

+ (void)addKarma:(NSNumber *)karmaToAdd
{
    Karma *karmaEntity = [
        NSEntityDescription insertNewObjectForEntityForName:@"Karma"
        inManagedObjectContext:[AppDelegate sharedManagedObjectContext]
    ];
    
    karmaEntity.karma = [NSNumber numberWithInt:([karmaEntity.karma intValue] + [karmaToAdd intValue])];
    
    NSError *error;
    if (![[AppDelegate sharedManagedObjectContext] save:&error]) {
        NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
    }
}

@end
