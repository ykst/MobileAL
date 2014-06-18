//
//  MALAudioADPCMEncoder.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/17.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MALRawAudioFreight.h"
#import "MALByteFreight.h"
#import "MALEncodedAudioFreight.h"

// IMA 4:1 ADPCM.
@interface MALAudioADPCMEncoder : NSObject

+ (instancetype)create;

- (BOOL)process:(MALRawAudioFreight *)src to:(MALEncodedAudioFreight *)dst;

@end
