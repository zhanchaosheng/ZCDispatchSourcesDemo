//
//  ViewController.m
//  ZCDispatchSourcesDemo
//
//  Created by zcs on 2017/1/10.
//  Copyright © 2017年 Zcoder. All rights reserved.
//

#import "ViewController.h"
#import "ZCDispatchSourcesController.h"

@interface ViewController () {
    dispatch_source_t _timer;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    ZCDispatchSourcesController *ctrl = [[ZCDispatchSourcesController alloc] init];
    _timer = [ctrl dispatchTimerWithInterval:5 handler:^{
        NSLog(@"-->Dispatch timer fire.");
    }];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
