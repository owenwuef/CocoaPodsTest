//
//  CPTViewController.m
//  CocoaPodsTest
//
//  Created by OwenWu on 10/3/14.
//  Copyright (c) 2014 OwenWu. All rights reserved.
//

#import "CPTViewController.h"

#import "AFNetworking.h"

#import "CPTTabViewController.h"

#import "CPTScanQRViewController.h"

#import "CPTLocationViewController.h"

@interface CPTViewController (){
    CPTTabViewController *theTabViewController;
    
    CPTScanQRViewController *theScanQRViewController;
    
    CPTLocationViewController *locationsViewController;
}
#pragma mark - UI Extras
@property (weak, nonatomic) IBOutlet UIWebView *logInWebView;
@end

@implementation CPTViewController

#pragma mark - Initialize View Controller Here
-(void)initializeViewController {
    // Create an instance of the microphone and tell it to use this view controller instance as the delegate
//    self.microphone = [EZMicrophone microphoneWithDelegate:self];
    _logInWebView.delegate = self;
    
    theTabViewController = [[CPTTabViewController alloc] init];
    theScanQRViewController = [[CPTScanQRViewController alloc] init];
    locationsViewController = [[CPTLocationViewController alloc] init];
}


#pragma mark - Initialization

//-(id)init {
//    self = [super init];
//    if(self){
//        [self initializeViewController];
//    }
//    return self;
//}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self){
        [self initializeViewController];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    switch ([AFNetworkReachabilityManager sharedManager].networkReachabilityStatus) {
        case AFNetworkReachabilityStatusUnknown:
            NSLog(@"AFNetworkReachabilityStatusUnknown");
            break;
        case AFNetworkReachabilityStatusReachableViaWiFi:
            NSLog(@"AFNetworkReachabilityStatusReachableViaWiFi");
            break;
        case AFNetworkReachabilityStatusReachableViaWWAN:
            NSLog(@"AFNetworkReachabilityStatusReachableViaWWAN");
            break;
        case AFNetworkReachabilityStatusNotReachable:
            NSLog(@"AFNetworkReachabilityStatusNotReachable");
            break;
            
        default:
            break;
    }
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    
    [_logInWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.baidu.com"] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60]];
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Action Extensions



#pragma mark - Actions

-(IBAction)btnOneTouchInsideUP:(id)sender
{
    NSInteger btnIdx = ((UIButton*)sender).tag;
    
    NSLog(@"%s:%ld",__FUNCTION__, (long)btnIdx);
    
    switch (btnIdx) {
        case 0:
            [self presentViewController:theScanQRViewController animated:YES completion:^(){
            }];
            break;
        case 1:
            [self presentViewController:locationsViewController animated:YES completion:^(){
            }];
            break;
        case 2:
//            [self presentViewController:nil animated:YES completion:^(){
//            }];
            break;
        case 3:
//            [self presentViewController:nil animated:YES completion:^(){
//            }];
            break;
            
        default:
            break;
    }
    
}

#pragma mark - UIWebViewDelegate Methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView{
}

- (void)webViewDidFinishLoad:(UIWebView *)webView{
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
}

@end
