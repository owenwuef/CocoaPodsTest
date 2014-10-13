//
//  TPEngine.h
//  ASR_library_iPhone
//
//  Created by Yongqing.Gu on 21/07/2010. 
//  Copyright 2010 Kingtas. All rights reserved.
//

#import <Foundation/Foundation.h>

// A singlton class to use Talkpal Speech Engine on iPad
@interface EFTPEngine : NSObject {
	BOOL mContextOK;
}

// Get the engine instance
+ (EFTPEngine*)getInstance;

// Init the engine with bin file supplied by Kingtas
// You must call this function before -setContextXml and -evaluateWaveFile
- (void)initWithEngineCoreBinFile: (NSString*)engineCoreBinFile;

// Set the speech evaluation context
// You must call -initWithEngineCoreBinFile before this function
- (void)setContextXml: (NSString*)xml;

// Evaluate a wave file
// You must call -setContextXml to set the speech evaluation context before this function
- (NSString*)evaluateWaveFile: (NSString*)waveFilePath;

// Evaluate a wave buffer
// buffer: a pointer that point to a PCM data buffer
// size: the size of the buffer in byte
- (NSString*)evaluateWaveBuffer: (void*)buffer withSize: (NSInteger)size;

// Close the engine, release the resource
// You can call -initWithEngineCoreBinFile again if you want to use the engine after calling this function
- (void)close;

@end
