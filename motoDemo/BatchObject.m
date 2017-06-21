//
//  BatchObject.m
//  Moto
//
//  Created by stephenw on 2017/6/20.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import "BatchObject.h"

@implementation ResponseObject

+ (NSDictionary *)JSONKeyPathForProperty {
  return @{
           @"code": @"code",
           @"body": @"body"
           };
}

@end

@implementation BatchObject

+ (NSDictionary *)JSONKeyPathForProperty {
  return @{
           @"entrances": @"entrances",
           @"espfullscreenpullconfig": @"espfullscreenpullconfig"
           };
}

@end
