// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/badges/badge_mediator.h"

#include "base/mac/foundation_util.h"
#include "base/metrics/user_metrics.h"
#include "ios/chrome/browser/infobars/infobar_badge_tab_helper.h"
#include "ios/chrome/browser/infobars/infobar_badge_tab_helper_delegate.h"
#include "ios/chrome/browser/infobars/infobar_metrics_recorder.h"
#import "ios/chrome/browser/infobars/infobar_type.h"
#import "ios/chrome/browser/ui/badges/badge_button.h"
#import "ios/chrome/browser/ui/badges/badge_consumer.h"
#import "ios/chrome/browser/ui/badges/badge_item.h"
#import "ios/chrome/browser/ui/badges/badge_static_item.h"
#import "ios/chrome/browser/ui/badges/badge_tappable_item.h"
#import "ios/chrome/browser/ui/commands/browser_coordinator_commands.h"
#import "ios/chrome/browser/ui/commands/infobar_commands.h"
#import "ios/chrome/browser/ui/list_model/list_model.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/chrome/browser/web_state_list/web_state_list_observer_bridge.h"
#include "ios/web/public/browser_state.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// The number of Fullscreen badges
const int kNumberOfFullScrenBadges = 1;
// The minimum number of non-Fullscreen badges to display the overflow popup
// menu.
const int kMinimumNonFullScreenBadgesForOverflow = 2;
}

@interface BadgeMediator () <InfobarBadgeTabHelperDelegate,
                             WebStateListObserving> {
  std::unique_ptr<WebStateListObserverBridge> _webStateListObserver;
}

// The WebStateList that this mediator listens for any changes on the active web
// state.
@property(nonatomic, assign) WebStateList* webStateList;

// Array of all available badges.
@property(nonatomic, strong) NSMutableArray<id<BadgeItem>>* badges;

// The consumer of the mediator.
@property(nonatomic, weak) id<BadgeConsumer> consumer;

@end

@implementation BadgeMediator
@synthesize webStateList = _webStateList;

- (instancetype)initWithConsumer:(id<BadgeConsumer>)consumer
                    webStateList:(WebStateList*)webStateList {
  self = [super init];
  if (self) {
    _consumer = consumer;
    _webStateList = webStateList;
    web::WebState* activeWebState = webStateList->GetActiveWebState();
    if (activeWebState) {
      [self updateNewWebState:activeWebState withWebStateList:webStateList];
    }
    _webStateListObserver = std::make_unique<WebStateListObserverBridge>(self);
    _webStateList->AddObserver(_webStateListObserver.get());
  }
  return self;
}

- (void)dealloc {
  [self disconnect];
}

- (void)disconnect {
  if (_webStateList) {
    _webStateList->RemoveObserver(_webStateListObserver.get());
    _webStateListObserver.reset();
    _webStateList = nullptr;
  }
}

#pragma mark - InfobarBadgeTabHelperDelegate

- (void)addInfobarBadge:(id<BadgeItem>)badgeItem {
  if (!self.badges) {
    self.badges = [NSMutableArray array];
  }
  [self.badges addObject:badgeItem];
  [self updateBadgesShown];
}

- (void)removeInfobarBadge:(id<BadgeItem>)badgeItem {
  for (id<BadgeItem> item in self.badges) {
    if (item.badgeType == badgeItem.badgeType) {
      [self.badges removeObject:item];
      [self updateBadgesShown];
      return;
    }
  }
}

- (void)updateInfobarBadge:(id<BadgeItem>)badgeItem {
  for (id<BadgeItem> item in self.badges) {
    if (item.badgeType == badgeItem.badgeType) {
      item.badgeState = badgeItem.badgeState;
      [self updateBadgesShown];
      return;
    }
  }
}

#pragma mark - BadgeDelegate

- (void)passwordsBadgeButtonTapped:(id)sender {
  BadgeButton* badgeButton = base::mac::ObjCCastStrict<BadgeButton>(sender);
  MobileMessagesBadgeState state;
  if (badgeButton.accepted) {
    state = MobileMessagesBadgeState::Active;
    base::RecordAction(
        base::UserMetricsAction("MobileMessagesBadgeAcceptedTapped"));
  } else {
    state = MobileMessagesBadgeState::Inactive;
    base::RecordAction(
        base::UserMetricsAction("MobileMessagesBadgeNonAcceptedTapped"));
  }
  InfobarMetricsRecorder* metricsRecorder;
  if (badgeButton.badgeType == BadgeType::kBadgeTypePasswordSave) {
    metricsRecorder = [[InfobarMetricsRecorder alloc]
        initWithType:InfobarType::kInfobarTypePasswordSave];
    [self.dispatcher displayModalInfobar:InfobarType::kInfobarTypePasswordSave];
  } else if (badgeButton.badgeType == BadgeType::kBadgeTypePasswordUpdate) {
    metricsRecorder = [[InfobarMetricsRecorder alloc]
        initWithType:InfobarType::kInfobarTypePasswordUpdate];
    [self.dispatcher
        displayModalInfobar:InfobarType::kInfobarTypePasswordUpdate];
  }
  [metricsRecorder recordBadgeTappedInState:state];
}

- (void)overflowBadgeButtonTapped:(id)sender {
  NSMutableArray<id<BadgeItem>>* popupMenuBadges =
      [[NSMutableArray alloc] init];
  // Get all non-fullscreen badges.
  for (id<BadgeItem> item in self.badges) {
    if (![item isFullScreen]) {
      [popupMenuBadges addObject:item];
    }
  }
  [self.dispatcher displayPopupMenuWithBadgeItems:popupMenuBadges];
  // TODO(crbug.com/976901): Add metric for this action.
}

#pragma mark - WebStateListObserver

- (void)webStateList:(WebStateList*)webStateList
    didReplaceWebState:(web::WebState*)oldWebState
          withWebState:(web::WebState*)newWebState
               atIndex:(int)atIndex {
  if (newWebState && newWebState == webStateList->GetActiveWebState()) {
    [self updateNewWebState:newWebState withWebStateList:webStateList];
  }
}

- (void)webStateList:(WebStateList*)webStateList
    didChangeActiveWebState:(web::WebState*)newWebState
                oldWebState:(web::WebState*)oldWebState
                    atIndex:(int)atIndex
                     reason:(int)reason {
  // Only attempt to retrieve badges if there is a new current web state, since
  // |newWebState| can be null.
  if (newWebState) {
    [self updateNewWebState:newWebState withWebStateList:webStateList];
  }
}

#pragma mark - Private

// Gets the last fullscreen and non-fullscreen badges.
// This assumes that there is only ever one fullscreen badge, so the last badge
// in |badges| should be the only one.
// TODO(crbug.com/976901): This is an arbitrary choice for non-fullscreen
// badges, though. This will be replaced by showing either one badge or the
// badge for the popup menu.
- (void)updateBadgesShown {
  id<BadgeItem> displayedBadge;
  id<BadgeItem> fullScreenBadge;
  for (id<BadgeItem> item in self.badges) {
    if ([item isFullScreen]) {
      fullScreenBadge = item;
    } else {
      displayedBadge = item;
    }
  }
  NSInteger count = [self.badges count];
  if (fullScreenBadge) {
    count -= kNumberOfFullScrenBadges;
  }
  if (count >= kMinimumNonFullScreenBadgesForOverflow) {
    displayedBadge = [[BadgeTappableItem alloc]
        initWithBadgeType:BadgeType::kBadgeTypeOverflow];
  }
  [self.consumer updateDisplayedBadge:displayedBadge
                      fullScreenBadge:fullScreenBadge];
}

- (void)updateNewWebState:(web::WebState*)newWebState
         withWebStateList:(WebStateList*)webStateList {
  DCHECK_EQ(_webStateList, webStateList);
  InfobarBadgeTabHelper* infobarBadgeTabHelper =
      InfobarBadgeTabHelper::FromWebState(newWebState);
  DCHECK(infobarBadgeTabHelper);
  infobarBadgeTabHelper->SetDelegate(self);
  // Whenever the WebState changes ask the corresponding
  // InfobarBadgeTabHelper for all the badges for that WebState.
  std::vector<id<BadgeItem>> infobarBadges =
      infobarBadgeTabHelper->GetInfobarBadgeItems();
  // Copy all contents of vector into array.
  self.badges = [[NSArray arrayWithObjects:&infobarBadges[0]
                                     count:infobarBadges.size()] mutableCopy];
  id<BadgeItem> displayedBadge;
  if ([self.badges count] > 1) {
    // Show the overflow menu badge when there are multiple badges.
    displayedBadge = [[BadgeTappableItem alloc]
        initWithBadgeType:BadgeType::kBadgeTypeOverflow];
  } else if ([self.badges count] == 1) {
    displayedBadge = [self.badges lastObject];
  }
  id<BadgeItem> fullScreenBadge;
  if (newWebState->GetBrowserState()->IsOffTheRecord()) {
    BadgeStaticItem* incognitoItem = [[BadgeStaticItem alloc]
        initWithBadgeType:BadgeType::kBadgeTypeIncognito];
    fullScreenBadge = incognitoItem;
    // Keep track of presence of an incognito badge so that the mediator knows
    // whether or not there is a fullscreen badge when calling
    // updateDisplayedBadge:fullScreenBadge:.
    [self.badges addObject:incognitoItem];
  }
  [self.consumer setupWithDisplayedBadge:displayedBadge
                         fullScreenBadge:fullScreenBadge];
}

@end
