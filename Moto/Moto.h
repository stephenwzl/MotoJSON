//
//  MotoCreator.h
//  Moto
//
//  Created by stephenw on 2017/6/19.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//


#import <Foundation/Foundation.h>

@protocol MTJSONSerializationHelper <NSObject>

+ (NSDictionary *)JSONKeyPathForProperty;

@end

typedef NSJSONWritingOptions MTJSONWritingOptions;
typedef NSJSONReadingOptions MTJSONReadingOptions;


@interface MTJSONSerialization : NSObject

//UTF8 string encoding specific
+ (id)JSONObjectWithString:(NSString *)string options:(MTJSONReadingOptions)opt error:(NSError **)error;
//any string encoding
+ (id)JSONObjectWithData:(NSData *)data options:(MTJSONReadingOptions)opt error:(NSError **)error;

@end
