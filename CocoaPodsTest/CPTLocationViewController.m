//
//  CPTLocationViewController.m
//  CocoaPodsTest
//
//  Created by OwenWu on 9/9/14.
//  Copyright (c) 2014 OwenWu. All rights reserved.
//

#import "CPTLocationViewController.h"

@interface CPTLocationViewController ()
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UIButton *getAddressButton;

@property (nonatomic, strong) CLGeocoder *geocoder;
@property (nonatomic, strong) MKPlacemark *placemark;
@end

@implementation CPTLocationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	   
    _mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0, 50, CGRectGetWidth(self.view.frame), 400)];
    [self.view addSubview:_mapView];
    
    _getAddressButton = [[UIButton alloc] initWithFrame:CGRectMake(150, 400, 80, 50)];
    [self.view addSubview:_getAddressButton];
    
    // Create a geocoder and save it for later.
    self.geocoder = [[CLGeocoder alloc] init];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"pushToDetail"])
    {
        // Get the destination view controller and set the placemark data that it should display.
//        PlacemarkViewController *viewController = segue.destinationViewController;
//        viewController.placemark = self.placemark;
    }
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    // Center the map the first time we get a real location change.
    static dispatch_once_t centerMapFirstTime;
    
    if ((userLocation.coordinate.latitude != 0.0) && (userLocation.coordinate.longitude != 0.0)) {
        dispatch_once(&centerMapFirstTime, ^{
            [self.mapView setCenterCoordinate:userLocation.coordinate animated:YES];
        });
    }
    
    // Lookup the information for the current location of the user.
    [self.geocoder reverseGeocodeLocation:self.mapView.userLocation.location completionHandler:^(NSArray *placemarks, NSError *error) {
        if ((placemarks != nil) && (placemarks.count > 0)) {
            // If the placemark is not nil then we have at least one placemark. Typically there will only be one.
            _placemark = [placemarks objectAtIndex:0];
            
            // we have received our current location, so enable the "Get Current Address" button
            [self.getAddressButton setEnabled:YES];
        }
        else {
            // Handle the nil case if necessary.
        }
    }];
}

@end
