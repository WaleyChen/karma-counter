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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    if ([textField.text length] > 0) {
        [Nickname setNickname:textField.text];
        
        // now that we have a nickname, load the "Karma" view
        [self.view removeFromSuperview];
        
        UIWindow *window = [[UIApplication sharedApplication].delegate window];
        UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Karma" bundle:nil];
        UIViewController *viewController = [storyBoard instantiateViewControllerWithIdentifier:@"KarmaViewController"];
        
        window.rootViewController = viewController;
        [window makeKeyAndVisible];
    }
    
    return NO;
}

@end
