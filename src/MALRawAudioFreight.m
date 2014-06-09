//
//  MCVAudioFreight.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/02.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MALRawAudioFreight.h"

@interface MALRawAudioFreight() {
}

@end


@implementation MALRawAudioFreight

+ (instancetype)createWithSamples:(size_t)num_samples withFormat:(MALRawAudioFormat)format withSamplingRate:(float)sampling_rate
{
    MALRawAudioFreight *obj = [[[self class] alloc] init];

    ASSERT([obj _setupWithSamples:num_samples withFormat:format withSamplingRate:sampling_rate], return nil);

    return obj;
}

- (BOOL)_setupWithSamples:(size_t)num_samples withFormat:(int)format withSamplingRate:(float)sampling_rate
{
    ASSERT((num_samples % 1024) == 0 && num_samples > 0, return NO);
    ASSERT(sampling_rate == 44100, return NO); // TODO: remove this constraint

    switch (format) {
        case MAL_RAWAUDIO_FORMAT_PCM_FLOAT32:
            _bytes_per_sample = 4;
            break;

        case MAL_RAWAUDIO_FORMAT_PCM_INT16:
            _bytes_per_sample = 2;
            break;

        default:
            NSASSERT(!"unexpected format");
            break;
    }

    _sampling_rate = sampling_rate;
    _num_samples = num_samples;
    _num_bytes = (int)_bytes_per_sample * (int)_num_samples;
    _format = format;

    _data = [NSMutableData dataWithLength:_num_bytes];

    [self reset];

    return YES;
}

- (BOOL)feed:(const float *)buf withSamples:(size_t)samples
{
    unsigned length = (unsigned)samples * (unsigned)_bytes_per_sample;

    return [self feedBytes:buf withLength:length];
}


@end
