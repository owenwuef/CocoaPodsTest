//
//  CPTViewController.m
//  CocoaPodsTest
//
//  Created by OwenWu on 10/3/14.
//  Copyright (c) 2014 OwenWu. All rights reserved.
//

#import "CPTViewController.h"
#import "AFNetworking.h"

@interface CPTViewController ()
#pragma mark - UI Extras
@property (nonatomic,weak) IBOutlet UILabel *microphoneTextLabel;
@end

@implementation CPTViewController

#pragma mark - Initialize View Controller Here
-(void)initializeViewController {
    // Create an instance of the microphone and tell it to use this view controller instance as the delegate
    self.microphone = [EZMicrophone microphoneWithDelegate:self];
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
    
    /*
     Customizing the audio plot's look
     */
    // Background color
    self.audioPlot.backgroundColor = [UIColor colorWithRed:0.984 green:0.471 blue:0.525 alpha:1.0];
    // Waveform color
    self.audioPlot.color           = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    // Plot type
    self.audioPlot.plotType        = EZPlotTypeBuffer;
    
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    /*
     Start the microphone
     */
    [self.microphone startFetchingAudio];
    self.microphoneTextLabel.text = @"Microphone On";
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Action Extensions
/*
 Give the visualization of the current buffer (this is almost exactly the openFrameworks audio input eample)
 */
-(void)drawBufferPlot {
    // Change the plot type to the buffer plot
    self.audioPlot.plotType = EZPlotTypeBuffer;
    // Don't mirror over the x-axis
    self.audioPlot.shouldMirror = NO;
    // Don't fill
    self.audioPlot.shouldFill = NO;
}

/*
 Give the classic mirrored, rolling waveform look
 */
-(void)drawRollingPlot {
    self.audioPlot.plotType = EZPlotTypeRolling;
    self.audioPlot.shouldFill = YES;
    self.audioPlot.shouldMirror = YES;
}

#pragma mark - Actions

-(IBAction)btnOneTouchInsideUP:(id)sender
{
    NSLog(@"%s",__FUNCTION__);
}

-(IBAction)changePlotType:(id)sender{
    NSInteger selectedSegment = [sender selectedSegmentIndex];
    switch(selectedSegment){
        case 0:
            [self drawBufferPlot];
            break;
        case 1:
            [self drawRollingPlot];
            break;
        default:
            break;
    }
}

-(IBAction)toggleMicrophone:(id)sender{
    if( ![(UISwitch*)sender isOn] ){
        [self.microphone stopFetchingAudio];
        self.microphoneTextLabel.text = @"Microphone Off";
    }
    else {
        [self.microphone startFetchingAudio];
        self.microphoneTextLabel.text = @"Microphone On";
    }
}

#pragma mark - EZMicrophoneDelegate
// Note that any callback that provides streamed audio data (like streaming microphone input) happens on a separate audio thread that should not be blocked. When we feed audio data into any of the UI components we need to explicity create a GCD block on the main thread to properly get the UI to work.
-(void)microphone:(EZMicrophone *)microphone
 hasAudioReceived:(float **)buffer
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
    // Getting audio data as an array of float buffer arrays. What does that mean? Because the audio is coming in as a stereo signal the data is split into a left and right channel. So buffer[0] corresponds to the float* data for the left channel while buffer[1] corresponds to the float* data for the right channel.
    
    // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blocking that audio flow.
    dispatch_async(dispatch_get_main_queue(),^{
        // All the audio plot needs is the buffer data (float*) and the size. Internally the audio plot will handle all the drawing related code, history management, and freeing its own resources. Hence, one badass line of code gets you a pretty plot :)
        [self.audioPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
    });
}

-(void)microphone:(EZMicrophone *)microphone hasAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription {
    // The AudioStreamBasicDescription of the microphone stream. This is useful when configuring the EZRecorder or telling another component what audio format type to expect.
    // Here's a print function to allow you to inspect it a little easier
    [EZAudio printASBD:audioStreamBasicDescription];
}

-(void)microphone:(EZMicrophone *)microphone
    hasBufferList:(AudioBufferList *)bufferList
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
    // Getting audio data as a buffer list that can be directly fed into the EZRecorder or EZOutput. Say whattt...
}

@end
