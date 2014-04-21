//
//  MCVByteFreight.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MCVByteFreight.h"

@implementation MCVByteFreight

+ (instancetype)createWithLength:(size_t)length
{
    MCVByteFreight *obj = [[[self class] alloc] init];

    [obj _setupWithLength:length];

    return obj;
}

+ (instancetype)createVariable
{
    MCVByteFreight *obj = [[[self class] alloc] init];

    [obj _setupVariable];

    return obj;
}

- (void)_setupWithLength:(size_t)length
{
    _num_bytes = length;
    _data = [NSMutableData dataWithLength:_num_bytes];
    _is_variable = NO;
    [self reset];
}

- (void)_setupVariable
{
    _num_bytes = 0;
    _data = [NSMutableData data];
    _is_variable = YES;
    [self reset];
}

- (void)reset
{
    _cursor = 0;
}

- (BOOL)feedBytes:(const void *)buf withLength:(size_t)length
{
    size_t next_cursor = _cursor + length;

    if (next_cursor > _num_bytes) {
        if (_is_variable) {
            //DBG("realloc %zu -> %zu bytes", _num_bytes, next_cursor);
            [_data increaseLengthBy:(next_cursor - _num_bytes)];
            _num_bytes = next_cursor;
        } else {
            WARN("potential buffer overrun");
            length = _num_bytes - _cursor;
            next_cursor = _num_bytes;
        }
    }

    if (length > 0) {
        [_data replaceBytesInRange:NSMakeRange(_cursor, length) withBytes:buf];
    }

    _cursor = next_cursor;

    return _cursor == _num_bytes;
}

- (BOOL)feedData:(NSData *)data
{
    return [self feedBytes:data.bytes withLength:data.length];
}

- (void *)invalidateRange:(size_t)length
{
    if (length + _cursor > _num_bytes) return NULL;

    void *ret = &(_data.mutableBytes[_cursor]);

    _cursor += length;

    return ret;
}

- (NSData *)extractWrittenData
{
    return [NSData dataWithBytesNoCopy:(void *)_data.bytes length:_cursor freeWhenDone:NO];
}

- (BOOL)filled
{
    return _cursor >= _num_bytes;
}

@end
