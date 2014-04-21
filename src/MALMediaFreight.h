//
//  VSMediaFreight.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/06.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MALByteFreight.h"
#import "MALTimeStampFreightProtocol.h"

@interface MALMediaFreight : MALByteFreight<MALTimeStampFreightProtocol> {
    @protected
    struct timeval _timestamp;
}
@property (nonatomic, readwrite) struct timeval timestamp;

@end
