//
//  VSEncodedAudioFreight.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/17.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "VSMediaFreight.h"

@interface VSEncodedAudioFreight : VSMediaFreight

typedef NS_ENUM(NSUInteger, VSEncodedAudioFormat) {
    VSENCODED_AUDIO_FORMAT_ADPCM = 1,
};
@property (nonatomic, readonly) VSEncodedAudioFormat format;
@property (nonatomic, readwrite) int16_t start_sample; // XXX: ADPCM specific
@property (nonatomic, readwrite) int16_t start_index; // XXX: ADPCM specific

+ (instancetype)createWithLength:(size_t)length withFormat:(VSEncodedAudioFormat)format;

@end
