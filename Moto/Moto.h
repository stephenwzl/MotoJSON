//
//  MotoCreator.h
//  Moto
//
//  Created by stephenw on 2017/6/19.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//


#import <Foundation/Foundation.h>
#if defined(DEBUG)
extern void motoDebugPrint(CFDictionaryRef _Nonnull dict);
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol MTJSONSerializationHelper <NSObject>

@required
+ (NSDictionary *)JSONKeyPathForProperty;

@end

typedef NSJSONWritingOptions MTJSONWritingOptions;
typedef NSJSONReadingOptions MTJSONReadingOptions;

@interface NSObject (MTJSONModel)

+ (instancetype _Nullable)instanceFromJSONString:(NSString *)jsonString;
+ (instancetype _Nullable)instanceFromJSONData:(NSData *)jsonData;

@end

NS_ASSUME_NONNULL_END
