//
//  MCVAudioFreight.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/02.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MALMediaFreight.h"

@interface MALRawAudioFreight : MALMediaFreight

typedef NS_ENUM(NSUInteger, MALRawAudioFormat)
{
    MAL_RAWAUDIO_FORMAT_PCM_FLOAT32 = 1,
    MAL_RAWAUDIO_FORMAT_PCM_INT16 = 2,
};

@property (nonatomic, readonly) float sampling_rate;
@property (nonatomic, readonly) size_t num_samples;
@property (nonatomic, readonly) size_t bytes_per_sample;
@property (nonatomic, readonly) MALRawAudioFormat format; // not used, PCM only

// format is unused
+ (instancetype)createWithSamples:(size_t)num_samples withFormat:(MALRawAudioFormat)format withSamplingRate:(float)sampling_rate;

- (BOOL)feed:(const float *)buf withSamples:(size_t)samples; // append data. return YES when the internal buffer was filled up
@end
