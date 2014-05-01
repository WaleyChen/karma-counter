//
//  Nickname.m
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-04-30.
//
//

#import "AppDelegate.h"
#import "Nickname.h"

@implementation Nickname

@dynamic nickname;

+ (NSString*)getNickname
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *nicknameEntity = [
        NSEntityDescription entityForName:@"Nickname"
        inManagedObjectContext:[AppDelegate sharedManagedObjectContext]
    ];
    [fetchRequest setEntity:nicknameEntity];
    
    NSError* error;
    NSArray *fetchedRecords = [
        [AppDelegate sharedManagedObjectContext] executeFetchRequest:fetchRequest error:&error
    ];
    
    if ([fetchedRecords count] == 0)
        return nil;
    
    return [(Nickname*)fetchedRecords[0] nickname];
}

+ (void)setNickname:(NSString *)nickname
{
    Nickname *nicknameEntity = [
        NSEntityDescription insertNewObjectForEntityForName:@"Nickname"
        inManagedObjectContext:[AppDelegate sharedManagedObjectContext]
    ];
    nicknameEntity.nickname = nickname;
    
    NSError *error;
    if (![[AppDelegate sharedManagedObjectContext] save:&error]) {
        NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
    }
}

@end
