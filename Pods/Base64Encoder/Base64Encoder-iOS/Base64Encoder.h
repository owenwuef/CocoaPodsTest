//
// Created by Yongwei on 3/19/14.
// Copyright (c) 2014 Yongwei. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Base64Encoder : NSObject

+ (void)initialize;
+ (NSString *)encode:(NSString*)string;
+ (NSString *)decode:(NSString*)string;

@end