// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_NTP_FEED_METRICS_RECORDER_H_
#define IOS_CHROME_BROWSER_UI_NTP_FEED_METRICS_RECORDER_H_

#import <UIKit/UIKit.h>

// DO NOT CHANGE. Values are from enums.xml representing what could be broken in
// the NTP view hierarchy. These values are persisted to logs. Entries should
// not be renumbered and numeric values should never be reused.
enum class BrokenNTPHierarchyRelationship {
  kContentSuggestionsParent = 0,
  kELMCollectionParent = 1,
  kDiscoverFeedParent = 2,
  kDiscoverFeedWrapperParent = 3,
  kContentSuggestionsReset = 4,
  kFeedHeaderParent = 5,
  kContentSuggestionsHeaderParent = 6,

  // Change this to match max value.
  kMaxValue = 6,
};

// Records different metrics for the NTP feeds.
@interface FeedMetricsRecorder : NSObject

// Record metrics for when the user has scrolled |scrollDistance| in the Feed.
- (void)recordFeedScrolled:(int)scrollDistance;

// Record metrics for when the user changes the device orientation with the feed
// visible.
- (void)recordDeviceOrientationChanged:(UIDeviceOrientation)orientation;

// Record metrics for when the user has tapped on the feed preview.
- (void)recordDiscoverFeedPreviewTapped;

// Record metrics for when the user selects the 'Learn More' item in the feed
// header menu.
- (void)recordHeaderMenuLearnMoreTapped;

// Record metrics for when the user selects the 'Manage' item in the feed header
// menu.
- (void)recordHeaderMenuManageTapped;

// Record metrics for when the user selects the 'Manage Activity' item in the
// feed header menu.
- (void)recordHeaderMenuManageActivityTapped;

// Record metrics for when the user selects the 'Manage Interests' item in the
// feed header menu.
- (void)recordHeaderMenuManageInterestsTapped;

// Record metrics for when the user selects the 'Hidden' item in the feed
// management UI.
- (void)recordHeaderMenuManageHiddenTapped;

// Record metrics for when the user selects the 'Following' item in the feed
// management UI.
- (void)recordHeaderMenuManageFollowingTapped;

// Record metrics for when the user toggles the feed visibility from the feed
// header menu.
- (void)recordDiscoverFeedVisibilityChanged:(BOOL)visible;

// Records metrics for when a user opens an article in the same tab.
- (void)recordOpenURLInSameTab;

// Records metrics for when a user opens an article in a new tab.
- (void)recordOpenURLInNewTab;

// Records metrics for when a user opens an article in an incognito tab.
- (void)recordOpenURLInIncognitoTab;

// Records metrics for when a user adds an article to the Reading List.
- (void)recordAddURLToReadLater;

// Records metrics for when a user opens the Send Feedback form.
- (void)recordTapSendFeedback;

// Records metrics for when a user opens the back of card menu.
- (void)recordOpenBackOfCardMenu;

// Records metrics for when a user closes the back of card menu.
- (void)recordCloseBackOfCardMenu;

// Records metrics for when a user opens the native back of card menu.
- (void)recordOpenNativeBackOfCardMenu;

// Records metrics for when a user displayed a Dialog (e.g. Report content
// dialog.)
- (void)recordShowDialog;

// Records metrics for when a user dismissed a Dialog (e.g. Report content
// dialog.)
- (void)recordDismissDialog;

// Records metrics for when a user dismissed a card (e.g. Hide story, not
// interested in, etc.)
- (void)recordDismissCard;

// Records metrics for when a user undos a dismissed card (e.g. Tapping Undo in
// the Snackbar)
- (void)recordUndoDismissCard;

// Records metrics for when a user committs to a dismissed card (e.g. Undo
// snackbar was dismissed, so Undo can no longer happen.)
- (void)recordCommittDismissCard;

// Records metrics for when a Snackbar has been shown.
- (void)recordShowSnackbar;

// Records an unknown |commandID| performed by the Feed.
- (void)recordCommandID:(int)commandID;

// Records if a notice card was presented at the time the feed was initially
// loaded. e.g. Launch time, user refreshes, and account switches.
- (void)recordNoticeCardShown:(BOOL)shown;

// Records if activity logging was enabled at the time the feed was initially
// loaded. e.g. Launch time, user refreshes, and account switches.
- (void)recordActivityLoggingEnabled:(BOOL)loggingEnabled;

// Records the |durationInSeconds| it took to Discover feed to Fetch articles.
// |success| is YES if operation was successful.
- (void)recordFeedArticlesFetchDurationInSeconds:
            (NSTimeInterval)durationInSeconds
                                         success:(BOOL)success;

// Records the |durationInSeconds| it took to Discover feed to Fetch more
// articles (e.g. New "infinite feed" articles). |success| is YES if operation
// was successful.
- (void)recordFeedMoreArticlesFetchDurationInSeconds:
            (NSTimeInterval)durationInSeconds
                                             success:(BOOL)success;

// Records the |durationInSeconds| it took to Discover feed to upload actions.
// |success| is YES if operation was successful.
- (void)recordFeedUploadActionsDurationInSeconds:
            (NSTimeInterval)durationInSeconds
                                         success:(BOOL)success;

// Records the native context menu visibility change.
- (void)recordNativeContextMenuVisibilityChanged:(BOOL)shown;

// Records the native pull-down menu visibility change.
- (void)recordNativePulldownMenuVisibilityChanged:(BOOL)shown;

// Records the broken view hierarchy before repairing it.
// TODO(crbug.com/1262536): Remove this when issue is fixed.
- (void)recordBrokenNTPHierarchy:
    (BrokenNTPHierarchyRelationship)brokenRelationship;

// Records that the feed is about to be refreshed.
- (void)recordFeedWillRefresh;

@end

#endif  // IOS_CHROME_BROWSER_UI_NTP_FEED_METRICS_RECORDER_H_
