//
//  VSMediaFreight.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/06.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MCVByteFreight.h"
#import "MCVTimeStampFreightProtocol.h"

@interface VSMediaFreight : MCVByteFreight<MCVTimeStampFreightProtocol> {
    @protected
    struct timeval _timestamp;
}
@property (nonatomic, readwrite) struct timeval timestamp;

@end
