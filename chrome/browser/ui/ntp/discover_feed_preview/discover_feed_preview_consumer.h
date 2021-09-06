// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_NTP_DISCOVER_FEED_PREVIEW_DISCOVER_FEED_PREVIEW_CONSUMER_H_
#define IOS_CHROME_BROWSER_UI_NTP_DISCOVER_FEED_PREVIEW_DISCOVER_FEED_PREVIEW_CONSUMER_H_

@protocol DiscoverFeedPreviewConsumer <NSObject>

// Updates the consumer with the current loading state.
- (void)setLoadingState:(BOOL)loading;

// Updates the consumer with the current progress of the WebState.
- (void)setLoadingProgressFraction:(double)progress;

@end

#endif  // IOS_CHROME_BROWSER_UI_NTP_DISCOVER_FEED_PREVIEW_DISCOVER_FEED_PREVIEW_CONSUMER_H_