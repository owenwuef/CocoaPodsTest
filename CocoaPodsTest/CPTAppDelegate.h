//
//  CPTAppDelegate.h
//  CocoaPodsTest
//
//  Created by OwenWu on 10/3/14.
//  Copyright (c) 2014 OwenWu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface CPTAppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) NSMutableArray *items;

@property (strong, nonatomic) CLLocationManager *locationManager;

@property (strong, nonatomic) UIWindow *window;

@end
