//
//  MotoCreator.h
//  Moto
//
//  Created by stephenw on 2017/6/19.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MTJSONSerializationHelper <NSObject>

@required
+ (NSDictionary *)JSONKeyPathForProperty;
@optional
+ (NSDictionary *)targetClassForPropertyKey;

@end

typedef NSJSONWritingOptions MTJSONWritingOptions;
typedef NSJSONReadingOptions MTJSONReadingOptions;

@interface NSObject (MTJSONModel)

+ (instancetype _Nullable)instanceFromJSONString:(NSString *)jsonString;
+ (instancetype _Nullable)instanceFromJSONData:(NSData *)jsonData;

@end

NS_ASSUME_NONNULL_END
