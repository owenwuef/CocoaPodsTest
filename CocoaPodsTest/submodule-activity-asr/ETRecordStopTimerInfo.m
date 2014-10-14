//
// Created by Yongwei on 3/19/14.
// Copyright (c) 2014 EF. All rights reserved.
//

#import "ETRecordStopTimerInfo.h"


@implementation ETRecordStopTimerInfo

- (id)initWithTimeout:(NSTimeInterval)silenceTimeout
{
    if ((self = [super init]))
    {

        self.recordStart = [NSDate date];
        self.silenceStart = [NSDate distantFuture];
        self.silenceTimeout = silenceTimeout;
    }

    return self;
}

@end