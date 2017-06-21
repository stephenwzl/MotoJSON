//
//  main.m
//  Moto
//
//  Created by stephenw on 2017/6/19.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Moto.h"
#import "MotoClassInfo.h"
#import <objc/runtime.h>

@interface SomeObj : NSObject<MTJSONSerializationHelper>

@property (nonatomic, strong) NSNumber *num;
@property (nonatomic, copy) NSString *string;
@property (nonatomic, strong) SomeObj *obj;

@end

@implementation SomeObj

+ (NSDictionary *)JSONKeyPathForProperty {
  return @{};
}

@end


int main(int argc, const char * argv[]) {
  CFMutableDictionaryRef infos = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
//  for (int i = 0; i < 100; i++) {
  Class cls = [SomeObj class];
  Class cls1 = [NSObject class];
  char* aaa = (char *)malloc(10);
  strcpy(aaa, "bbbbb");
  CFDictionarySetValue(infos, (__bridge void *)cls, aaa);
//  }
  return 0;
}
