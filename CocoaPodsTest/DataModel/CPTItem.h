//
//  CPTItem.h
//  CocoaPodsTest
//
//  Created by OwenWu on 28/4/14.
//  Copyright (c) 2014 OwenWu. All rights reserved.
//

#import "BaseModel.h"

@interface CPTItem : BaseModel

@property (nonatomic, strong) NSUUID *uuid;
@property (nonatomic, strong) NSString *name;

@property (nonatomic) short majorValue;
@property (nonatomic) short minorValue;

@end
