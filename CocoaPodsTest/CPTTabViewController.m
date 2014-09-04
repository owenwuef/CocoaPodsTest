//
//  CPTTabViewController.m
//  CocoaPodsTest
//
//  Created by OwenWu on 4/9/14.
//  Copyright (c) 2014 OwenWu. All rights reserved.
//

#import "CPTTabViewController.h"

@interface CPTTabViewController ()

@end

@implementation CPTTabViewController

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
    // Do any additional setup after loading the view.
    UIButton *backButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 20, 200, 50)];
    backButton.backgroundColor = [UIColor blackColor];
    [backButton setTitle:@"Back" forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(backToPrevious) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];
    
    self.view.backgroundColor = [UIColor whiteColor];
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

-(void)backToPrevious{
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
