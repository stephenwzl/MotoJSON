//
//  ViewController.m
//  motoDemo
//
//  Created by stephenw on 2017/6/20.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import "ViewController.h"
#import "Moto.h"
#import "BatchObject.h"
#import <YYModel/YYModel.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  NSString *path = [[NSBundle mainBundle] pathForResource:@"demo" ofType:@"json"];
  NSString *json = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
  printf("benchmark: (s):\n");
  [self doFoundationModelWithJSON:json];
  printf("\n\n");
  [self doYYModelWithJSON:json];
  printf("\n\n");
  [self doMTModelWithJSON:json];
}

- (void)doFoundationModelWithJSON:(NSString *)json {
  clock_t start, finish;
  start = clock();
  for (int i = 0; i < 10000; ++i) {
    [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:NULL];
  }
  finish = clock();
  printf("10k times Foundation JSON Serialization time consumed: \n\n");
  printf("   %lf\n", (double)(finish - start)/CLOCKS_PER_SEC);
}

- (void)doYYModelWithJSON:(NSString *)json {
  clock_t start, finish;
  start = clock();
  for (int i = 0; i < 10000; ++i) {
    [BatchObject yy_modelWithJSON:json];
  }
  finish = clock();
  printf("10k times YYModel JSON Serialization time consumed: \n\n");
  printf("   %lf\n", (double)(finish - start)/CLOCKS_PER_SEC);
}

- (void)doMTModelWithJSON:(NSString *)json {
  clock_t start, finish;
  start = clock();
  for (int i = 0; i < 10000; ++i) {
    [BatchObject instanceFromJSONString:json];
  }
  finish = clock();
  printf("10k times MTModel JSON Serialization time consumed: \n\n");
  printf("   %lf\n", (double)(finish - start)/CLOCKS_PER_SEC);
}


@end
