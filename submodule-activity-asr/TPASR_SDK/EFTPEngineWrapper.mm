//
//  EFTPEngineWrapper.m
//  efekta-activity-web
//
//  Created by Yongwei on 3/18/14.
//  Copyright (c) 2014 EF. All rights reserved.
//

#import "EFTPEngineWrapper.h"
#import "EFTPEngine.h"

@interface EFTPEngineWrapper ()

@property (nonatomic, strong) EFTPEngine *engine;

@end

@implementation EFTPEngineWrapper

#pragma mark - Setup

-(id)init
{
    self = [super init];
    
//    _engine = [[EFTPEngine getInstance] retain];
    _engine = [EFTPEngine getInstance];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"TPEngineCoreKB" ofType:@"bin"];
    [_engine initWithEngineCoreBinFile:path];
    
    return self;
}


-(void)dealloc
{
    // Close and release the engine
    
    /*
     The following line is commented out since it makes the engine crash.
     Needs further investigation
     */
    // TODO: Investigate need for -close
    // [_engine close];
    
//    [_engine release];
//    
//    [super dealloc];
}


#pragma mark - Implementation

-(NSString *)evaluateWaveFile:(NSURL *)waveFileUrl forContextXml:(NSString *)contextXml
{
    // Get wave file
    NSString *path = [waveFileUrl relativePath];
    
    // Set context xml
    [_engine setContextXml:contextXml];
    
    // Run engine
    NSString *result = [_engine evaluateWaveFile:path];
    
    // Return result
    return result;
}

@end
