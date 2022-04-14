// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/follow/followed_web_channel.h"

#include "base/strings/sys_string_conversions.h"
#import "ios/chrome/browser/net/crurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation FollowedWebChannel

- (instancetype)initWithTitle:(NSString*)title
                   channelURL:(CrURL*)channelURL
                   faviconURL:(CrURL*)faviconURL
                    available:(BOOL)available
         unfollowRequestBlock:(FollowRequestBlock)unfollowRequestBlock
         refollowRequestBlock:(FollowRequestBlock)refollowRequestBlock {
  self = [super init];
  if (self) {
    _title = title;
    _channelURL = channelURL;
    _faviconURL = faviconURL;
    _available = available;
    _unfollowRequestBlock = unfollowRequestBlock;
    _refollowRequestBlock = refollowRequestBlock;
  }
  return self;
}

#pragma mark - NSObject

- (BOOL)isEqualToFollowedWebChannel:(FollowedWebChannel*)channel {
  return channel && [self.title isEqualToString:channel.title] &&
         self.channelURL.gurl == channel.channelURL.gurl &&
         self.faviconURL.gurl == channel.faviconURL.gurl &&
         self.available == channel.available;
}

- (BOOL)isEqual:(id)object {
  if (self == object)
    return YES;

  if (![object isMemberOfClass:[FollowedWebChannel class]])
    return NO;

  return [self isEqualToFollowedWebChannel:object];
}

- (NSUInteger)hash {
  return [self.title hash] ^
         [base::SysUTF8ToNSString(self.channelURL.gurl.spec()) hash] ^
         [base::SysUTF8ToNSString(self.faviconURL.gurl.spec()) hash] ^
         self.available;
}

@end
