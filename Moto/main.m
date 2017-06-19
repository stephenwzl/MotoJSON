//
//  main.m
//  Moto
//
//  Created by stephenw on 2017/6/19.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Moto.h"

int main(int argc, const char * argv[]) {
  @autoreleasepool {
      NSString *json = @"{\"hello\": true}";
    NSDictionary *dict = [MTJSONSerialization JSONObjectWithString:json options:NSJSONReadingMutableLeaves error:NULL];
    NSLog(@"%@", dict);
  }
  return 0;
}
