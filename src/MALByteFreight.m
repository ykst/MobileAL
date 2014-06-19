//
//  MCVByteFreight.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MALByteFreight.h"

#define REALLOC(t,num,action) ({ \
    typeof(t) __t = (t); \
    typeof(num) __num = (num); \
    size_t __sz = (__num) * sizeof(*(t)); \
    if(unlikely(!(__t = (typeof(t))realloc((t),__sz)))) { \
        ERROR("Cannot realloc %zuB\n", __sz); \
        action; \
    } \
    (t) = __t; \
})

@interface MALByteFreight()
@end

@implementation MALByteFreight

+ (instancetype)createWithLength:(size_t)length
{
    MALByteFreight *obj = [[[self class] alloc] init];

    [obj _setupWithLength:length];

    return obj;
}

+ (instancetype)createVariable
{
    MALByteFreight *obj = [[[self class] alloc] init];

    [obj _setupVariable];

    return obj;
}

- (void)_setupWithLength:(size_t)length
{
    _num_bytes = (unsigned)length;
    _buf = malloc(_num_bytes);
    _is_variable = NO;

    [self reset];
}

- (void)_setupVariable
{
    _num_bytes = 0;
    _buf = NULL;

    _is_variable = YES;

    [self reset];
}

- (void)reset
{
    _cursor = 0;
}

- (BOOL)feedBytes:(const void *)buf withLength:(size_t)length
{
    int next_cursor = _cursor + (int)length;

    if (next_cursor > _num_bytes) {
        if (_is_variable) {
            REALLOC(_buf, next_cursor, ({ NSASSERT(!"Realloc Failed"); return NO; }));
            _num_bytes = next_cursor;
        } else {
            WARN("potential buffer overrun");
            length = _num_bytes - _cursor;
            next_cursor = _num_bytes;
        }
    }

    if (length > 0) {
        memcpy(&_buf[_cursor], buf, length);
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
    if (length + _cursor > _num_bytes) {
        return NULL;
    }

    void *ret = &_buf[_cursor];

    _cursor += length;

    return ret;
}

- (NSData *)extractWrittenData
{
    return [NSData dataWithBytesNoCopy:_buf length:_cursor freeWhenDone:NO];
}

- (NSData *)data
{
    return [NSData dataWithBytesNoCopy:_buf length:_num_bytes freeWhenDone:NO];
}

- (NSData *)retrieveData
{
    NSData *ret = [NSData dataWithBytesNoCopy:_buf length:_num_bytes freeWhenDone:YES];

    _buf = NULL;

    return ret;
}

- (BOOL)filled
{
    return _cursor >= _num_bytes;
}

- (void)dealloc
{
    FREE(_buf);
}

@end
