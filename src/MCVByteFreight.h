//
//  MCVByteFreight.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MobileCV/MCVFreight.h>

@interface MCVByteFreight : MCVFreight {
    @protected
    NSMutableData *_data;
    int _cursor;
    size_t _num_bytes;
    BOOL _is_variable;
}

@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) size_t num_bytes;
@property (nonatomic, readonly) int cursor;
@property (nonatomic, readonly) BOOL filled;

+ (instancetype)createWithLength:(size_t)length;
+ (instancetype)createVariable;
- (void)reset; // move writing cursor to initial position
- (BOOL)feedBytes:(const void *)buf withLength:(size_t)length; // return YES when filled
- (BOOL)feedData:(NSData *)data; // return YES when filled
- (void *)invalidateRange:(size_t)length; // return NULL when cursor overruns maximum length
- (NSData *)extractWrittenData;
@end
