//
//  VSEncodedAudioFreight.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/17.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "VSEncodedAudioFreight.h"

@interface VSEncodedAudioFreight()
@property (nonatomic, readwrite) VSEncodedAudioFormat format;
@end

@implementation VSEncodedAudioFreight

+ (instancetype)createWithLength:(size_t)length withFormat:(VSEncodedAudioFormat)format
{
    ASSERT(format == VSENCODED_AUDIO_FORMAT_ADPCM, return nil);

    VSEncodedAudioFreight *obj = [[self class] createWithLength:length];

    obj.format = format;

    return obj;
}
@end
