//
//  BatchObject.h
//  Moto
//
//  Created by stephenw on 2017/6/20.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Moto.h"

@interface ResponseObject : NSObject <MTJSONSerializationHelper>

@property (nonatomic, copy) NSNumber *code;
@property (nonatomic, copy) NSString *body;

@end

@interface BatchObject : NSObject <MTJSONSerializationHelper>

@property (nonatomic, strong) ResponseObject *entrances;
@property (nonatomic, strong) ResponseObject *espfullscreenpullconfig;

@end
