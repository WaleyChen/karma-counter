//
//  KarmaViewController.m
//  iOS_karma_waley
//
//  Created by Waley Chen on 2014-05-01.
//
//

#import "Nickname.h"
#import "KarmaViewController.h"

@interface KarmaViewController ()

@property (weak, nonatomic) IBOutlet UILabel *NicknameLabel;

@end

@implementation KarmaViewController

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
    
    [self NicknameLabel].text = [NSString stringWithFormat:@"%@%@", [Nickname getNickname], @"'s Karma"];;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
