// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/badges/badge_popup_menu_coordinator.h"

#include "base/metrics/histogram_macros.h"
#include "base/notreached.h"
#include "ios/chrome/browser/infobars/infobar_ios.h"
#include "ios/chrome/browser/infobars/infobar_manager_impl.h"
#include "ios/chrome/browser/infobars/infobar_metrics_recorder.h"
#import "ios/chrome/browser/infobars/infobar_type.h"
#import "ios/chrome/browser/infobars/overlays/infobar_overlay_request_inserter.h"
#import "ios/chrome/browser/main/browser.h"
#include "ios/chrome/browser/overlays/public/overlay_request_queue.h"
#import "ios/chrome/browser/ui/badges/badge_constants.h"
#import "ios/chrome/browser/ui/badges/badge_item.h"
#import "ios/chrome/browser/ui/badges/badge_popup_menu_item.h"
#import "ios/chrome/browser/ui/badges/badges_histograms.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/infobar_commands.h"
#import "ios/chrome/browser/ui/infobars/infobar_feature.h"
#import "ios/chrome/browser/ui/popup_menu/public/cells/popup_menu_item.h"
#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_consumer.h"
#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_presenter.h"
#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_presenter_delegate.h"
#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_table_view_controller.h"
#import "ios/chrome/browser/ui/popup_menu/public/popup_menu_table_view_controller_delegate.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_item.h"
#import "ios/chrome/browser/ui/util/layout_guide_names.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface BadgePopupMenuCoordinator () <PopupMenuPresenterDelegate,
                                         PopupMenuTableViewControllerDelegate>

// The PopupMenuTableViewController managed by this coordinator.
@property(nonatomic, strong) PopupMenuTableViewController* popupViewController;

// The presenter of |popupViewController|.
@property(nonatomic, strong) PopupMenuPresenter* popupMenuPresenter;

// The consumer of the coordinator.
@property(nonatomic, weak) id<PopupMenuConsumer> consumer;

// The items to display.
@property(nonatomic, strong)
    NSArray<NSArray<TableViewItem<PopupMenuItem>*>*>* popupMenuItems;

@end

@implementation BadgePopupMenuCoordinator

- (void)start {
  self.popupViewController = [[PopupMenuTableViewController alloc] init];
  self.popupViewController.baseViewController = self.baseViewController;
  self.popupViewController.delegate = self;
  self.popupViewController.tableView.accessibilityIdentifier =
      kBadgePopupMenuTableViewAccessibilityIdentifier;
  self.consumer = self.popupViewController;
  [self.consumer setPopupMenuItems:self.popupMenuItems];
  self.popupMenuPresenter = [[PopupMenuPresenter alloc] init];
  self.popupMenuPresenter.baseViewController = self.baseViewController;
  self.popupMenuPresenter.presentedViewController = self.popupViewController;
  self.popupMenuPresenter.guideName = kBadgeOverflowMenuGuide;
  self.popupMenuPresenter.delegate = self;
  [self.popupMenuPresenter prepareForPresentation];
  [self.popupMenuPresenter presentAnimated:YES];
}

- (void)stop {
  [self dismissPopupMenu];
  self.popupViewController = nil;
}

- (void)setBadgeItemsToShow:(NSArray<id<BadgeItem>>*)badgeItems {
  NSMutableArray<TableViewItem<PopupMenuItem>*>* items =
      [[NSMutableArray alloc] init];
  for (id<BadgeItem> item in badgeItems) {
    BadgePopupMenuItem* badgePopupMenuItem =
        [[BadgePopupMenuItem alloc] initWithBadgeType:[item badgeType]];
    [items addObject:badgePopupMenuItem];
  }
  self.popupMenuItems = @[ items ];
  [self.consumer setPopupMenuItems:self.popupMenuItems];
}

#pragma mark - PopupMenuPresenterDelegate

- (void)popupMenuPresenterWillDismiss:(PopupMenuPresenter*)presenter {
  [self dismissPopupMenu];
}

#pragma mark - PopupMenuTableViewControllerDelegate

- (void)popupMenuTableViewController:(PopupMenuTableViewController*)sender
                       didSelectItem:(TableViewItem<PopupMenuItem>*)item
                              origin:(CGPoint)origin {
  [self dismissPopupMenu];
  switch (item.actionIdentifier) {
    case PopupMenuActionShowSavePasswordOptions: {
      UMA_HISTOGRAM_ENUMERATION(kInfobarOverflowMenuTappedHistogram,
                                MobileMessagesInfobarType::SavePassword);
      [self
          addModalRequestForInfobarType:InfobarType::kInfobarTypePasswordSave];
      break;
    }
    case PopupMenuActionShowUpdatePasswordOptions: {
      UMA_HISTOGRAM_ENUMERATION(kInfobarOverflowMenuTappedHistogram,
                                MobileMessagesInfobarType::UpdatePassword);
      [self addModalRequestForInfobarType:InfobarType::
                                              kInfobarTypePasswordUpdate];
      break;
    }
    case PopupMenuActionShowSaveCardOptions: {
      UMA_HISTOGRAM_ENUMERATION(kInfobarOverflowMenuTappedHistogram,
                                MobileMessagesInfobarType::SaveCard);
      [self addModalRequestForInfobarType:InfobarType::kInfobarTypeSaveCard];
      break;
    }
    case PopupMenuActionShowTranslateOptions: {
      UMA_HISTOGRAM_ENUMERATION(kInfobarOverflowMenuTappedHistogram,
                                MobileMessagesInfobarType::Translate);
      [self addModalRequestForInfobarType:InfobarType::kInfobarTypeTranslate];
      break;
    }
    default:
      NOTREACHED() << "Unexpected identifier";
      break;
  }
}

#pragma mark - Private

// Adds a modal request for the Infobar of |infobarType|.
- (void)addModalRequestForInfobarType:(InfobarType)infobarType {
  if (base::FeatureList::IsEnabled(kInfobarOverlayUI)) {
    web::WebState* webState =
        self.browser->GetWebStateList()->GetActiveWebState();
    DCHECK(webState);
    InfoBarIOS* infobar = [self infobarWithType:infobarType];
    DCHECK(infobar);
    InfobarOverlayRequestInserter::CreateForWebState(webState);
    InsertParams params(infobar);
    params.overlay_type = InfobarOverlayType::kModal;
    params.insertion_index = OverlayRequestQueue::FromWebState(
                                 webState, OverlayModality::kInfobarModal)
                                 ->size();
    params.source = InfobarOverlayInsertionSource::kBadge;
    InfobarOverlayRequestInserter::FromWebState(webState)->InsertOverlayRequest(
        params);
  } else {
    id<InfobarCommands> handler = HandlerForProtocol(
        self.browser->GetCommandDispatcher(), InfobarCommands);
    [handler displayModalInfobar:infobarType];
  }
}

// Retrieves the existing Infobar of |type|.
- (InfoBarIOS*)infobarWithType:(InfobarType)type {
  InfoBarManagerImpl* manager = InfoBarManagerImpl::FromWebState(
      self.browser->GetWebStateList()->GetActiveWebState());
  for (size_t index = 0; index < manager->infobar_count(); ++index) {
    InfoBarIOS* infobar = static_cast<InfoBarIOS*>(manager->infobar_at(index));
    if (infobar->infobar_type() == type)
      return infobar;
  }
  return nullptr;
}

- (void)dismissPopupMenu {
  if (self.popupMenuPresenter) {
    [self.popupMenuPresenter dismissAnimated:YES];
    self.popupMenuPresenter = nil;
  }
}

@end
