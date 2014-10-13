//
// Created by Yongwei on 3/19/14.
// Copyright (c) 2014 EF. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ETBase64Encoder : NSObject

+ (void)initialize;
+ (NSString *)encode:(NSData*)rawBytes;
+ (NSData *)decode:(NSString*)string;

@end