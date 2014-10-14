//
//  EFASREngine.h
//  efekta-activity-web
//
//  Created by Yongwei on 3/18/14.
//  Copyright (c) 2014 EF. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class EFTPEngineWrapper;


@protocol EFASREngineDelegate <NSObject>

-(void)endRunASRWithXMLResult:(NSString*)result;
-(void)startASREvent;
-(void)passRecordPower:(float)aver;

@end


@interface EFASREngine : NSObject <AVAudioPlayerDelegate, AVAudioRecorderDelegate, UIAlertViewDelegate>

@property (nonatomic, retain) UIWebView *webView;
@property (nonatomic, assign) BOOL nativeMode;   // YES for native activity template, NO for HTML version
@property (nonatomic, assign)   id<EFASREngineDelegate> delegate;
@property (nonatomic, strong) NSString *prons;
@property (nonatomic, assign) BOOL autoStop;

- (void)handleMessage:(NSDictionary *)msg;

- (void)startRecording:(NSTimeInterval)maxDuration timeout:(NSTimeInterval)timeout;
- (void)stopRecording;
- (void)startPlayback:(NSString *)fileName;
- (void)stopPlayback;
- (void)runASR:(NSString *)fileName withEncodedXml:(NSString *)encodedXml;
- (void)runASRWithEncodedXml:(NSString *)encodedXml;

- (void)didReceiveMemoryWarning;


@end
