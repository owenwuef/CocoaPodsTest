//
//  EFTPEngineWrapper.h
//  efekta-activity-web
//
//  Created by Yongwei on 3/18/14.
//  Copyright (c) 2014 EF. All rights reserved.
//

#import <Foundation/Foundation.h>

@class EFTPEngine;

@interface EFTPEngineWrapper : NSObject

-(NSString *)evaluateWaveFile:(NSURL *)waveFileUrl forContextXml:(NSString *)contextXml;

@end
