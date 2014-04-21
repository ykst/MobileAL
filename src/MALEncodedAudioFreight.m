//
//  VSEncodedAudioFreight.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/17.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MALEncodedAudioFreight.h"

@interface MALEncodedAudioFreight()
@property (nonatomic, readwrite) VSEncodedAudioFormat format;
@end

@implementation MALEncodedAudioFreight

+ (instancetype)createWithLength:(size_t)length withFormat:(VSEncodedAudioFormat)format
{
    ASSERT(format == MAL_ENCODED_AUDIO_FORMAT_ADPCM, return nil);

    MALEncodedAudioFreight *obj = [[self class] createWithLength:length];

    obj.format = format;

    return obj;
}
@end
