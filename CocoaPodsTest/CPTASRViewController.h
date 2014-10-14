//
//  CPTASRViewController.h
//  CocoaPodsTest
//
//  Created by OwenWu on 14/10/14.
//  Copyright (c) 2014 OwenWu. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PocketsphinxController;

#import <OpenEars/OpenEarsEventsObserver.h> // We need to import this here in order to use the delegate.

@interface CPTASRViewController : UIViewController <OpenEarsEventsObserverDelegate> {
    // These three are important OpenEars classes that ViewController demonstrates the use of. There is a fourth important class (LanguageModelGenerator) demonstrated
    // inside the ViewController implementation in the method viewDidLoad.
    
    OpenEarsEventsObserver *openEarsEventsObserver; // A class whose delegate methods which will allow us to stay informed of changes in the Flite and Pocketsphinx statuses.
    PocketsphinxController *pocketsphinxController; // The controller for Pocketsphinx (voice recognition).
    
    // Our NSTimer that will help us read and display the input and output levels without locking the UI
    NSTimer *uiUpdateTimer;
}

@property (nonatomic, strong) OpenEarsEventsObserver *openEarsEventsObserver;
@property (nonatomic, strong) PocketsphinxController *pocketsphinxController;

// Our NSTimer that will help us read and display the input and output levels without locking the UI
@property (nonatomic, strong) 	NSTimer *uiUpdateTimer;

@property (nonatomic, assign) BOOL usingStartLanguageModel;
@property (nonatomic, assign) int restartAttemptsDueToPermissionRequests;
@property (nonatomic, assign) BOOL startupFailedDueToLackOfPermissions;

// Things which help us show off the dynamic language features.
@property (nonatomic, copy) NSString *pathToFirstDynamicallyGeneratedLanguageModel;
@property (nonatomic, copy) NSString *pathToFirstDynamicallyGeneratedDictionary;
@property (nonatomic, copy) NSString *pathToSecondDynamicallyGeneratedLanguageModel;
@property (nonatomic, copy) NSString *pathToSecondDynamicallyGeneratedDictionary;

@end
