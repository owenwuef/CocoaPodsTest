//
//  EFASREngine.m
//  efekta-activity-web
//
//  Created by Yongwei on 3/18/14.
//  Copyright (c) 2014 EF. All rights reserved.
//

#import "EFASREngine.h"
#import "EFTPEngineWrapper.h"
#import "ETRecordStopTimerInfo.h"
#import "Base64Encoder.h"

@interface EFASREngine()
{
    EFTPEngineWrapper *_engine;
    AVAudioRecorder *_recorder;
    AVAudioPlayer *_player;
    NSTimer *_timer;
    NSString *_tempWaveFileName;
}

@end

@implementation EFASREngine

void pauseActivityMedia(){
//    UIWebView *webView = [EFWebView getWebViewInstance];
//    if (webView != nil) {
//        [webView stringByEvaluatingJavaScriptFromString:@"window.ET.NA.Activity.pauseMedia();"];
//    }
}

void audioRouteChangeListenerCallback (
                                       void                      *inUserData,
                                       AudioSessionPropertyID    inPropertyID,
                                       UInt32                    inPropertyValueSize,
                                       const void                *inPropertyValue
                                       ) {
	
	// ensure that this callback was invoked for a route change
	if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return;
   	
    // Determines the reason for the route change, to ensure that it is not
    //		because of a category change.
    CFDictionaryRef	routeChangeDictionary = inPropertyValue;
    
    CFNumberRef routeChangeReasonRef =
    CFDictionaryGetValue (
                          routeChangeDictionary,
                          CFSTR (kAudioSession_AudioRouteChangeKey_Reason)
                          );
    
    SInt32 routeChangeReason;
    
    CFNumberGetValue (
                      routeChangeReasonRef,
                      kCFNumberSInt32Type,
                      &routeChangeReason
                      );
    
    // "Old device unavailable" indicates that a headset was unplugged, or that the
    //	device was removed from a dock connector that supports audio output. This is
    //	the recommended test for when to pause audio.
    if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) {
        pauseActivityMedia();
        NSLog (@"Output device removed, so application audio was paused.");
        
    } else {
        
        NSLog (@"A route change occurred that does not require pausing of application audio.");
    }
    
}

#pragma mark -
#pragma mark UIAlertViewDelegate
// Called when we cancel a view (eg. the user clicks the Home button). This is not called when the user clicks the cancel button.
// If not defined in the delegate, we simulate a click in the cancel button
- (void)alertViewCancel:(UIAlertView *)alertView
{
}

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self stopRecording];
    
    if (self.prons) {
        
        if ([self.delegate conformsToProtocol:@protocol(EFASREngineDelegate)] && [self.delegate respondsToSelector:@selector(startASREvent)]) {
            [self.delegate startASREvent];
        }
        [self runASRWithEncodedXml:self.prons];
    }
}

#pragma mark -
#pragma mark AVAudioPlayerDelegate

- (void) audioPlayerBeginInterruption:(AVAudioPlayer *)player
{
	[_player stop];
}


- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    
}


- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
	
	NSString *script = @"ET.NA.ASR.playbackComplete();";
	[self.webView stringByEvaluatingJavaScriptFromString:script];
    
}


- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player
{
    
}


#pragma mark -
#pragma mark AVAudioRecorderDelegate

- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder
{
    DLog(@"%s",__PRETTY_FUNCTION__);
    if (_recorder) {
      	[_recorder stop];
    }
}


- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    DLog(@"%s",__PRETTY_FUNCTION__);
	if (_timer)
	{
		[_timer invalidate];
		//[_timer release];
		_timer = nil;
	}
    if (_recorder) {
        _recorder = nil;
    }
    
    if (!self.autoStop) {
        if (self && self.nativeMode == NO ) {
            if (self.webView) {
                NSArray *components = [[recorder.url path] pathComponents];
                NSString *fileName = [components objectAtIndex:(components.count -1)];
                NSString *script = [NSString stringWithFormat:@"ET.NA.ASR.recordingComplete('%@')", fileName];
                [self.webView stringByEvaluatingJavaScriptFromString:script];
            }
        }
    }
    
    
}


- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
    DLog(@"Error %s",__PRETTY_FUNCTION__);
}


- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder
{
    DLog(@"Error %s",__PRETTY_FUNCTION__);
}


#pragma mark -
#pragma mark Implementation

- (void)handleURL:(NSURL *)url
{
	
	NSString *method = [[url host] lowercaseString];
	
	if ([method isEqualToString:@"asr.startrecording"])
	{
		NSArray *components = [[url path] pathComponents];
		
		NSTimeInterval recordDuration = 0;
		NSTimeInterval autoStopTimeout = 0;
		
		if ([components count] > 2)
		{
			NSString *val = [components objectAtIndex:1];
			recordDuration = [val doubleValue] / 1000;
            
			val = [components objectAtIndex:2];
			autoStopTimeout = [val doubleValue] / 1000;
		}
        
		[self startRecording:recordDuration timeout:autoStopTimeout];
        
		return;
	}
	
	if ([method isEqualToString:@"asr.stoprecording"])
	{
		[self stopRecording];
		return;
	}
	
	if ([method isEqualToString:@"asr.startplayback"])
	{
		NSString *fileName = [[url path] substringFromIndex:1];
		[self startPlayback:fileName];
		return;
	}
	
	if ([method isEqualToString:@"asr.stopplayback"])
	{
		[self stopPlayback];
		return;
	}
	
	if ([method isEqualToString:@"asr.run"])
	{
		NSString *path = [url path];
		int index;
		BOOL found = NO;
		
		for (index = 1; index < [path length]; index++)
		{
			if ([path characterAtIndex:index] == '/')
			{
				found = YES;
				break;
			}
		}
        
		if (found)
		{
			NSString *fileName = [[path substringToIndex:index] substringFromIndex:1];
			NSString *encodedXml = [path substringFromIndex:(index + 1)];
			
			[self runASR:fileName withEncodedXml:encodedXml];
		}
        
		return;
	}
    
}

- (void)handleMessage:(NSDictionary *)msg
{
	NSString *action = [[msg objectForKey:@"action"] lowercaseString];
	
	if ([action isEqualToString:@"startrecording"])
	{
        
		NSTimeInterval recordDuration = 0;
		NSTimeInterval autoStopTimeout = 0;
		
		id value = [msg objectForKey:@"maxDuration"];
		if ([value respondsToSelector:@selector(doubleValue)])
		{
			recordDuration = [value doubleValue] / 1000;
		}
        
		value = [msg objectForKey:@"autoStopTimeout"];
		if ([value respondsToSelector:@selector(doubleValue)])
		{
			autoStopTimeout = [value doubleValue] / 1000;
		}
        
		[self startRecording:recordDuration timeout:autoStopTimeout];
		
	}
	else if ([action isEqualToString:@"stoprecording"])
	{
		[self stopRecording];
	}
	else if ([action isEqualToString:@"startplayback"])
	{
		[self startPlayback:[msg objectForKey:@"fileName"]];
	}
	else if ([action isEqualToString:@"stopplayback"])
	{
		[self stopPlayback];
	}
	else if ([action isEqualToString:@"run"])
	{
        // why delay 3 seconds? it makes user thinks our asr performance is bad.
        //        double delayInSeconds = 3.0;
        double delayInSeconds = 0.1;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_current_queue(), ^(void){
            
            [self stopRecording];
            [self runASR:[msg objectForKey:@"fileName"] withEncodedXml:[msg objectForKey:@"contextXml"]];
            
        });
        
        
	}
	
}


- (void)startRecording:(NSTimeInterval)maxDuration timeout:(NSTimeInterval)timeout
{
    //@OWEN MOBILE-2264
#ifndef __IPHONE_7_0
#else
    if([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)])
    {
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            if (granted) {
                // Microphone enabled code
                NSLog(@"Microphone is enabled in iOS 7..");
            }
            else {
                // Microphone disabled code
                [[[UIAlertView alloc] initWithTitle:@"You have not given this application permission to use your microphone."
                                            message:[NSString stringWithFormat:@"%@\n%@",
                                                            @"Please go to your iPad Settings &gt; Privacy &gt; Microphone and enable access to the microphone for this application.",
                                                            @"Then try this activity again."
                                            ]
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil] show];
                NSLog(@"Microphone is disabled in iOS 7..");
            }
        }];
    }
#endif
    
	// Release any existing recorder
	if (_recorder)
	{
		if (_recorder.recording)
		{
			[_recorder stop];
		}
		_recorder = nil;
        return; // return out, don't continue. Because the [_recorder stop] already triggered the 'audioRecorderDidFinishRecording' callback.
        
	}
	
	// Ensure timer isn't running
	if ([_timer isValid])
	{
		[_timer invalidate];
		_timer = nil;
	}
	
	// If duration is missing (or less than 1 second), default to 5 mins
	if (maxDuration < 1)
	{
		maxDuration = 300.0f;
	}
    
	// If timeout is missing (or less than 1 second), default to 1.5 seconds
	if (timeout < 1)
	{
		timeout = 1.5f;
	}
	
	
	// Setup recorder for ASR wave format
	NSMutableDictionary* settings = [[NSMutableDictionary alloc] init];
	[settings setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
	[settings setValue:[NSNumber numberWithFloat:16000.0] forKey:AVSampleRateKey];
	[settings setValue:[NSNumber numberWithInt: 1] forKey:AVNumberOfChannelsKey];
	[settings setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
	[settings setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
	[settings setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
    
	// Generate unique file name in temporary folder path
	NSString *fileName = [[NSString alloc] initWithFormat:@"%f.wav", [[NSDate date] timeIntervalSince1970]]; // [NSString stringWithFormat:@"%f.wav", [[NSDate date] timeIntervalSince1970]];
    _tempWaveFileName = fileName;
	NSURL *url = [self getTempFileURL:fileName];
    
#ifdef DEBUG
	DLog(@"Recording file %@", url.absoluteString);
#endif
    
    
	
	NSError *_recorderError;
	
	_recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&_recorderError];
	_recorder.delegate = self;
	_recorder.meteringEnabled = YES;

	[_recorder recordForDuration:maxDuration];
	
	if (_recorder.recording)
	{
		ETRecordStopTimerInfo *info = [[ETRecordStopTimerInfo alloc] initWithTimeout:timeout];
		
		_timer = [NSTimer timerWithTimeInterval:0.25f target:self selector:@selector(timerRecordSilence:) userInfo:info repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];

	}
	
}


- (void)stopRecording
{
	if (_recorder.recording)
	{
		[_recorder stop];
	}
}


- (void)startPlayback:(NSString *)fileName
{
    
	[self stopRecording];
	
	NSURL *url = [self getTempFileURL:fileName];
    
#ifdef DEBUG
	DLog(@"Playing file %@", fileName);
#endif
    
	if (_player)
	{
		if (_player.playing)
		{
			[_player stop];
		}
		_player = nil;
	}
    
	NSError *_playerError;
    
	_player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&_playerError];
	_player.delegate = self;
	
	[_player play];
	
}


- (void)stopPlayback
{
	if (_player.playing)
	{
		[_player stop];
		[self audioPlayerDidFinishPlaying:_player successfully:YES];
	}
}

- (void)runASRWithEncodedXml:(NSString *)encodedXml{
    NSAssert(_tempWaveFileName != nil , @"_tempWaveFileName can not be nil ");
    [self runASR:_tempWaveFileName withEncodedXml:encodedXml];
}

- (void)runASR:(NSString *)fileName withEncodedXml:(NSString *)contextXml
{
    
	NSURL *url = [self getTempFileURL:fileName];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]])
	{
		[self onASRError:NSLocalizedStringFromTable(@"ASR_ERROR_MISSING_AUDIO_FILE", @"asr", nil)];
#ifdef DEBUG
		DLog(@"File does not exist at path: %@", [url path]);
#endif
		return;
	}
    NSString *decodedXml = [Base64Encoder decode:contextXml];
	if (!decodedXml)
	{
		[self onASRError:NSLocalizedStringFromTable(@"ASR_ERROR_MISSING_CONTEXTXML", @"asr", nil)];
#ifdef DEBUG
		DLog(@"Could not decode context xml: %@", contextXml);
#endif
		return;
	}
    
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:&error];
#ifdef DEBUG
    NSLog(@"Size of file at %@, is %llu", [url path], [attributes fileSize]);
#endif
    if (error || [attributes fileSize] <= 1024*8) { //when the file size is too small the memory management bug in ASR lib leads into a crash
        [self onASRError:NSLocalizedStringFromTable(@"ASR_ERROR_MISSING_AUDIO_FILE", @"asr", nil)];
        NSLog(@"file too small");
        return;
    }

	if (!decodedXml)
	{
		[self onASRError:NSLocalizedStringFromTable(@"ASR_ERROR_INVALID_CONTEXTXML", @"asr", nil)];
#ifdef DEBUG
		DLog(@"Could not decode context xml: %@", contextXml);
#endif
		return;
	}
	
	if (!_engine)
	{
		_engine = [[EFTPEngineWrapper alloc] init];
	}
    
#ifdef DEBUG
	//DLog(@"Running ASR for wave file %@ with context xml \n\r%@", fileName, decodedXml);
#endif
    
	NSString *result = [_engine evaluateWaveFile:url forContextXml:decodedXml];
    
#ifdef DEBUG
    DLog(@"%@",result);
#endif
	
    if (self.nativeMode) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(endRunASRWithXMLResult:)] && _tempWaveFileName ) {
            [self.delegate endRunASRWithXMLResult:result];
        }
        
    }else{
        NSString *script = [NSString stringWithFormat:@"ET.NA.ASR.asrComplete('%@');", result];
        [self.webView stringByEvaluatingJavaScriptFromString:script];
    }
}

- (void)didReceiveMemoryWarning
{
	
	// Release the ASR engine
	_engine = nil;
	
	// Stop recorder if currently recording
	[self stopRecording];
	_recorder = nil;
    
	// Stop player if currently playing
	[self stopPlayback];
	_player = nil;
	
}

#pragma mark -
#pragma mark Overrides

- (id)init
{
	
	if ((self = [super init]))
	{
		
		// Get shared audio session
		AVAudioSession *audioSession = [AVAudioSession sharedInstance];
		
        
        NSError *_sessionError;
    
		// Setup session for record and playback
		[audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&_sessionError];
		
        OSStatus propertySetError = 0;
        UInt32 allowMixing = true;
        propertySetError = AudioSessionSetProperty ( kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof (allowMixing), &allowMixing);
        if (propertySetError != kAudioSessionNoError) {
            NSLog(@"%ld",propertySetError);
        }

        // Registers the audio route change listener callback function
        AudioSessionAddPropertyListener (
                                         kAudioSessionProperty_AudioRouteChange,
                                         audioRouteChangeListenerCallback,
                                         (__bridge void *)(self)
                                         );
        
		// Activate the session
		[audioSession setActive:YES error:&_sessionError];
		
        //[self performSelectorInBackground:@selector(removeTempASRFiles) withObject:nil];
	}
	
	return self;
}

- (void)dealloc
{
	[_timer invalidate];
}


#pragma mark -
#pragma mark Private Methods

- (NSURL *)getTempFileURL:(NSString *)fileName
{
	
	NSFileManager *fileMgr = [NSFileManager defaultManager];


    NSString *dir = [[EFASREngine PrivateAppDirectory] stringByAppendingPathComponent:@"AsrTmp"];

    [EFASREngine CreateDir:dir];


    NSString *path = [[EFASREngine CoursewareTempDirectory] stringByAppendingFormat:@"asr"];
	
	if (![fileMgr fileExistsAtPath:path])
	{
 		[fileMgr createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
	}
	
	if (fileName)
	{
		path = [path stringByAppendingPathComponent:fileName];
	}
    
	NSURL *url = [NSURL fileURLWithPath:path];
	
	return url;
	
}

+ (NSString*) CoursewareTempDirectory{
    NSString *dir = [[EFASREngine PrivateAppDirectory] stringByAppendingPathComponent:@"AsrTmp"];

    [EFASREngine CreateDir:dir];

    return dir;
}


+ (NSString*) PrivateAppDirectory{
    NSString *libDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *priAppDir = [libDir stringByAppendingPathComponent:@"Private Documents"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:priAppDir]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:priAppDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            DLog(@"FAILED TO CREATE %@",priAppDir);
        }

        [EFASREngine DoNotBackupToiCloud:priAppDir];

    }


    return priAppDir;
}

+ (BOOL)CreateDir:(NSString*)dirPath{
    if (![[NSFileManager defaultManager] fileExistsAtPath:dirPath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            DLog(@"FAILED TO CREATE %@",dirPath);
            return NO;
        }

        [EFASREngine DoNotBackupToiCloud:dirPath];
    }

    return YES;
}

+ (void)DoNotBackupToiCloud:(NSString*)documentString{
    NSURL *docURL = [[NSURL alloc] initFileURLWithPath:documentString];

    if (&NSURLIsExcludedFromBackupKey == NULL) {
        // Use iOS 5.0.1 mechanism
        const char *filePath = [[docURL path] fileSystemRepresentation];

        const char *attrName = "com.apple.MobileBackup";
        u_int8_t attrValue = 1;

        setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
    } else {
        // Use NSURLIsExcludedFromBackupKey mechanism, iOS 5.1+
        NSError *error = nil;
        BOOL success = [docURL setResourceValue:[NSNumber numberWithBool:YES]
                                      forKey:NSURLIsExcludedFromBackupKey
                                       error:&error];
        //Check your error and take appropriate action
        DLog(@"add skip backup %d for %@",success, [docURL path]);
    }
}

- (void)timerRecordSilence:(NSTimer *)timer
{
	// Ensure timer has not been invalidated
	if (![timer isValid])
	{
		return;
	}
    
    // Peak power should range between -160 dB (minimum power near silence) and 0 dB
	float avg = 0.;
    
    [_recorder updateMeters];
    if (_recorder) {
        avg = [_recorder averagePowerForChannel:0];
    }
#ifdef DEBUG
    DLog(@"Average record power %f dB (peak %f dB).", avg, [_recorder peakPowerForChannel:0]);
#endif
    
    if ([self.delegate conformsToProtocol:@protocol(EFASREngineDelegate)] && [self.delegate respondsToSelector:@selector(passRecordPower:)]) {
        [self.delegate passRecordPower:avg];
    }
	
	ETRecordStopTimerInfo *info = [timer userInfo];
	
	NSTimeInterval duration = -[info.recordStart timeIntervalSinceNow];
	
	// Give at least 2 seconds before checking for silence
	if (duration <= 2)
	{
		return;
	}
	
    if (_recorder) {
        avg = [_recorder averagePowerForChannel:0];
        
        //#ifdef DEBUG
        //        DLog(@"Average record power %f dB (peak %f dB).", avg, [_recorder peakPowerForChannel:0]);
        //#endif
        //   [_recorder updateMeters];
        
        if (avg < -30)
        {
            duration = -[info.silenceStart timeIntervalSinceNow];
            
            if (duration < 0)
            {
                info.silenceStart = [NSDate date];
            }
            else if (duration >= info.silenceTimeout)
            {
                [self stopRecording];
                
                if (self.prons) {
                    
                    if ([self.delegate conformsToProtocol:@protocol(EFASREngineDelegate)] && [self.delegate respondsToSelector:@selector(startASREvent)]) {
                        [self.delegate startASREvent];
                    }
                    [self runASRWithEncodedXml:self.prons];
                }
                
            }
            
        }
        else if ([info.silenceStart timeIntervalSinceNow] < 0)
        {
            info.silenceStart = [NSDate distantFuture];
        }
        
    }
    
}

- (void)onASRError:(NSString *)msg
{
	
	NSString *script = [NSString stringWithFormat:@"ET.NA.ASR.asrComplete('<TPResult version=\"1.0\" error=\"%@\"></TPResult>');", msg];
	[self.webView stringByEvaluatingJavaScriptFromString:script];
    
}


@end
