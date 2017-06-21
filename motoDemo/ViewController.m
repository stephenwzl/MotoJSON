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

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  NSString *path = [[NSBundle mainBundle] pathForResource:@"demo" ofType:@"json"];
  NSString *json = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
  BatchObject *obj = [BatchObject instanceFromJSONString:json];
  NSLog(@"%@", obj);
}


- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}


@end
