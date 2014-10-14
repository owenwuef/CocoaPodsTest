//
// Created by Yongwei on 3/19/14.
// Copyright (c) 2014 EF. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ETRecordStopTimerInfo : NSObject

@property (nonatomic, strong) NSDate *recordStart;
@property (nonatomic, strong) NSDate *silenceStart;
@property (nonatomic) NSTimeInterval silenceTimeout;

- (id)initWithTimeout:(NSTimeInterval)silenceTimeout;

@end