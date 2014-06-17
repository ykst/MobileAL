//
//  MCVByteFreight.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

// We manage raw pointer to reduce allocation/releasing overhead.
// This is because this data structure will be likely used in realtime,
// especially in Remote-IO threads which should return immediately.
@interface MALByteFreight : NSObject {
    @protected
    void *_buf;
    int _cursor;
    int _num_bytes;
    BOOL _is_variable;
    BOOL _is_prealloc;
}

//@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) void *buf;
@property (nonatomic, readonly) int num_bytes;
@property (nonatomic, readonly) int cursor;
@property (nonatomic, readonly) BOOL filled;

+ (instancetype)createWithLength:(size_t)length;
+ (instancetype)createVariable;
+ (instancetype)createPrealloc;
- (NSData *)data; // instanciate NSData from buf on the fly
- (void)reset; // move writing cursor to initial position
- (BOOL)feedBytes:(const void *)buf withLength:(size_t)length; // return YES when filled
- (BOOL)feedPreallocBytes:(void *)buf withLength:(size_t)length; // give the ownership of 'buf' to the instance. 'buf' will be freed when done.
- (BOOL)feedData:(NSData *)data; // return YES when filled
- (void *)invalidateRange:(size_t)length; // return NULL when cursor overruns maximum length
- (NSData *)extractWrittenData;
@end
