//
//  CPTViewController.h
//  CocoaPodsTest
//
//  Created by OwenWu on 10/3/14.
//  Copyright (c) 2014 OwenWu. All rights reserved.
//

#import <UIKit/UIKit.h>

// Import EZAudio header
#import "EZAudio.h"

@interface CPTViewController : UIViewController <EZMicrophoneDelegate>

@property (nonatomic, retain) IBOutlet UIButton *btnOne;

#pragma mark - Components
/**
 The CoreGraphics based audio plot
 */
@property (nonatomic,weak) IBOutlet EZAudioPlot *audioPlot;

/**
 The microphone component
 */
@property (nonatomic,strong) EZMicrophone *microphone;

#pragma mark - Actions
/**
 Switches the plot drawing type between a buffer plot (visualizes the current stream of audio data from the update function) or a rolling plot (visualizes the audio data over time, this is the classic waveform look)
 */
-(IBAction)changePlotType:(id)sender;

/**
 Toggles the microphone on and off. When the microphone is on it will send its delegate (aka this view controller) the audio data in various ways (check out the EZMicrophoneDelegate documentation for more details);
 */
-(IBAction)toggleMicrophone:(id)sender;

@end
