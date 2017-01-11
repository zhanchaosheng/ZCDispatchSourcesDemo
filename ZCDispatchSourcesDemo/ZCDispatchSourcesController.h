//
//  ZCDispatchSourcesController.h
//  ZCDispatchSourcesDemo
//
//  Created by zcs on 2017/1/10.
//  Copyright © 2017年 Zcoder. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZCDispatchSourcesController : NSObject
- (dispatch_source_t)dispatchTimerWithInterval:(NSUInteger)interval
                                       handler:(dispatch_block_t)block;
- (void)watcherForPath:(NSString *)aPath;
@end
