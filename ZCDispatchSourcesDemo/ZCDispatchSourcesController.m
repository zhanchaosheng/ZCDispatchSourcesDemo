//
//  ZCDispatchSourcesController.m
//  ZCDispatchSourcesDemo
//
//  Created by zcs on 2017/1/10.
//  Copyright © 2017年 Zcoder. All rights reserved.
//

/**
 // 可创建的 dispatch Source 的类型
 DISPATCH_SOURCE_TYPE_TIMER     定时响应
 DISPATCH_SOURCE_TYPE_SIGNAL    接收到UNIX信号时响应
 
 DISPATCH_SOURCE_TYPE_READ      IO操作，如对文件的操作、socket操作的读响应
 DISPATCH_SOURCE_TYPE_WRITE     IO操作，如对文件的操作、socket操作的写响应
 DISPATCH_SOURCE_TYPE_VNODE     文件状态监听，文件被删除、移动、重命名
 DISPATCH_SOURCE_TYPE_PROC      进程监听,如进程的退出、创建一个或更多的子线程、进程收到UNIX信号
 DISPATCH_SOURCE_TYPE_MACH_SEND
 DISPATCH_SOURCE_TYPE_MACH_RECV 上面2个都属于Mach相关事件响应
 DISPATCH_SOURCE_TYPE_DATA_ADD
 DISPATCH_SOURCE_TYPE_DATA_OR   上面2个都属于自定义的事件，并且也是有自己来触发
 */

#import "ZCDispatchSourcesController.h"
#import "MonitorFileChangeHelp.h"

@interface ZCDispatchSourcesController ()

@end

@implementation ZCDispatchSourcesController

#pragma mark - Timer dispatch source：定期产生通知
- (dispatch_source_t)dispatchTimerWithInterval:(NSUInteger)interval
                                       handler:(dispatch_block_t)block {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (source) {
        uint64_t leeway = 0ull * NSEC_PER_SEC; // 精确度
        // 根据挂钟时间来跟踪；而 DISPATCH_TIME_NOW 使用默认时钟，会受计算机睡眠影响
        dispatch_time_t start = dispatch_walltime(NULL, 0);
        dispatch_source_set_timer(source, start, interval * NSEC_PER_SEC, leeway);
        dispatch_source_set_event_handler(source,block);
        dispatch_resume(source);
    }
    return source;
}

#pragma mark - Signal dispatch source：UNIX信号到达时产生通知
- (dispatch_source_t)installSignalHandler:(dispatch_block_t)block {
    // 忽略该信号，阻止应用程序终止
    signal(SIGHUP, SIG_IGN);
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGHUP, 0, queue);
    if (source) {
        dispatch_source_set_event_handler(source, block);
        dispatch_resume(source);
    }
    return source;
}

#pragma mark - Process dispatch source：进程相关的事件通知
- (dispatch_source_t)monitorParentProcess:(dispatch_block_t)block {
    pid_t parentPID = getppid();
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC,
                                                      parentPID,
                                                      DISPATCH_PROC_EXIT,
                                                      queue);
    if (source) {
        dispatch_source_set_event_handler(source, block);
        dispatch_resume(source);
    }
    return source;
}

#pragma mark - Custom dispatch source：你自己定义并自己触发
- (void)installCustomDiapatchSource {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, queue);
    dispatch_source_set_event_handler(source,^{
        NSLog(@"监听函数：%lu",dispatch_source_get_data(source));
    });
    dispatch_resume(source);
    
    dispatch_queue_t myqueue =dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(myqueue, ^ {
        int i;
        for(i = 0;i<4;i++){
            dispatch_source_merge_data(source,i); // 主动触发
        } 
    });
}

#pragma mark - Descriptor dispatch source：各种文件和socket操作的通知

// 从描述符中读取数据
- (dispatch_source_t)processContentsOfFile:(NSString *)filename
{
    // 打开文件获得句柄
    int fd = open([filename fileSystemRepresentation], O_RDONLY);
    if (fd == -1) {
        return NULL;
    }
    fcntl(fd, F_SETFL, O_NONBLOCK);  // 配置文件描述符执行非阻塞操作
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, queue);
    if (!readSource) {
        close(fd);
        return NULL;
    }
    
    dispatch_source_set_event_handler(readSource, ^{
        size_t estimated = dispatch_source_get_data(readSource) + 1;
        // 读取数据到一个 text buffer.
        char* buffer = (char*)malloc(estimated);
        if (buffer) {
            ssize_t actual = read(fd, buffer, (estimated));
            
            // 出来读取的数据
            // ...

            free(buffer);
        }
    });
    
    dispatch_source_set_cancel_handler(readSource, ^{
        close(fd);
    });
    
    dispatch_resume(readSource);
    return readSource;
}

// 向描述符写入数据
- (dispatch_source_t)writeDataToFile:(const char*) filename
{
    int fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC,
                  (S_IRUSR | S_IWUSR | S_ISUID | S_ISGID));
    if (fd == -1) {
        return NULL;
    }
    fcntl(fd, F_SETFL); // 配置文件描述符执行非阻塞操作
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t writeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE,
                                                           fd, 0, queue);
    if (!writeSource) {
        close(fd);
        return NULL;
    }
    
    dispatch_source_set_event_handler(writeSource, ^{
        size_t bufferSize = 0;//写数据的大小 MyGetDataSize()
        void* buffer = malloc(bufferSize);
        
        size_t actual = 0; //获取要写的数据 MyGetData(buffer, bufferSize)
        write(fd, buffer, actual);
        
        free(buffer);
        
        // 写完后取消
        dispatch_source_cancel(writeSource);
    });
    
    dispatch_source_set_cancel_handler(writeSource, ^{close(fd);});
    dispatch_resume(writeSource);
    return writeSource;
}

- (void)watcherForPath:(NSString *)aPath {
    MonitorFileChangeHelp *fileMonitor = [MonitorFileChangeHelp new];
    [fileMonitor watcherForPath:aPath block:^(NSInteger type) {
        if (type == DISPATCH_VNODE_ATTRIB) {
            NSLog(@"Test file's DISPATCH_VNODE_ATTRIB changed.");
        }
        else if (type == DISPATCH_VNODE_DELETE) {
            NSLog(@"Test file's DISPATCH_VNODE_DELETE changed.");
        }
        else if (type ==  DISPATCH_VNODE_EXTEND) {
            NSLog(@"Test file's DISPATCH_VNODE_EXTEND changed.");
        }
        else if (type ==  DISPATCH_VNODE_LINK) {
            NSLog(@"Test file's DISPATCH_VNODE_LINK changed.");
        }
        else if (type ==  DISPATCH_VNODE_RENAME){
            NSLog(@"Test file's DISPATCH_VNODE_RENAME changed.");
        }
        else if (type ==  DISPATCH_VNODE_REVOKE) {
            NSLog(@"Test file's DISPATCH_VNODE_REVOKE changed.");
        }
        else if (type == DISPATCH_VNODE_WRITE) {
            NSLog(@"Test file's DISPATCH_VNODE_WRITE changed.");
        }
        
    }];
}

@end
