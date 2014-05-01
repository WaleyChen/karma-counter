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
    
    NSEntityDescription *entity = [
        NSEntityDescription entityForName:@"Nickname"
        inManagedObjectContext:[AppDelegate sharedManagedObjectContext]
    ];
    
    [fetchRequest setEntity:entity];
    
    NSError* error;
    NSArray *fetchedRecords = [
        [AppDelegate sharedManagedObjectContext] executeFetchRequest:fetchRequest error:&error
    ];
    
    if ([fetchedRecords count] == 0)
        return nil;
    
    Nickname *nicknameEntity = fetchedRecords[0];
    return nicknameEntity.nickname;
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
