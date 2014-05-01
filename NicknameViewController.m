//
//  NicknameViewController.m
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-04-30.
//
//

#import "AppDelegate.h"
#import "Nickname.h"
#import "NicknameViewController.h"

@interface NicknameViewController ()

@end

@implementation NicknameViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.nicknameTextField.delegate = self;
    
    // Check if nickname has been chosen
    if ([self getNickname] == nil)
        NSLog(@"No nickname set.");
    else
        NSLog(@"Nickname is %@.", [self getNickname]);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    [self setNickname:textField.text];
    
    return NO;
}

- (NSString*)getNickname
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

- (void)setNickname:(NSString *)nickname
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
