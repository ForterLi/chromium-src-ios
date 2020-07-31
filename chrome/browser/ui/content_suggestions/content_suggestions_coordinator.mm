// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_coordinator.h"

#include "base/mac/foundation_util.h"
#include "base/metrics/user_metrics.h"
#include "base/metrics/user_metrics_action.h"
#include "base/scoped_observer.h"
#include "components/feed/core/shared_prefs/pref_names.h"
#include "components/ntp_snippets/content_suggestions_service.h"
#include "components/ntp_snippets/pref_names.h"
#include "components/ntp_snippets/remote/remote_suggestions_scheduler.h"
#include "components/ntp_tiles/most_visited_sites.h"
#include "components/prefs/pref_service.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/drag_and_drop/drag_and_drop_flag.h"
#import "ios/chrome/browser/drag_and_drop/url_drag_drop_handler.h"
#include "ios/chrome/browser/favicon/ios_chrome_large_icon_cache_factory.h"
#include "ios/chrome/browser/favicon/ios_chrome_large_icon_service_factory.h"
#include "ios/chrome/browser/favicon/large_icon_cache.h"
#import "ios/chrome/browser/main/browser.h"
#include "ios/chrome/browser/ntp_snippets/ios_chrome_content_suggestions_service_factory.h"
#include "ios/chrome/browser/ntp_tiles/ios_most_visited_sites_factory.h"
#include "ios/chrome/browser/pref_names.h"
#include "ios/chrome/browser/reading_list/reading_list_model_factory.h"
#include "ios/chrome/browser/search_engines/template_url_service_factory.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#include "ios/chrome/browser/signin/identity_manager_factory.h"
#import "ios/chrome/browser/ui/alert_coordinator/action_sheet_coordinator.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/browser_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/open_new_tab_command.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_most_visited_item.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_data_sink.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_feature.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_header_synchronizer.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_header_view_controller.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_mediator.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_menu_provider.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_metrics_recorder.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_view_controller.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_view_controller_audience.h"
#import "ios/chrome/browser/ui/content_suggestions/discover_feed_menu_commands.h"
#import "ios/chrome/browser/ui/content_suggestions/ntp_home_constant.h"
#import "ios/chrome/browser/ui/content_suggestions/ntp_home_mediator.h"
#import "ios/chrome/browser/ui/content_suggestions/ntp_home_metrics.h"
#import "ios/chrome/browser/ui/content_suggestions/theme_change_delegate.h"
#import "ios/chrome/browser/ui/menu/action_factory.h"
#import "ios/chrome/browser/ui/menu/menu_histograms.h"
#import "ios/chrome/browser/ui/ntp/new_tab_page_header_constants.h"
#import "ios/chrome/browser/ui/ntp/notification_promo_whats_new.h"
#import "ios/chrome/browser/ui/overscroll_actions/overscroll_actions_controller.h"
#import "ios/chrome/browser/ui/settings/utils/pref_backed_boolean.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/browser/url_loading/url_loading_browser_agent.h"
#import "ios/chrome/browser/url_loading/url_loading_params.h"
#import "ios/chrome/browser/voice/voice_search_availability.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#import "ios/public/provider/chrome/browser/discover_feed/discover_feed_provider.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface ContentSuggestionsCoordinator () <
    ContentSuggestionsMenuProvider,
    ContentSuggestionsViewControllerAudience,
    DiscoverFeedMenuCommands,
    OverscrollActionsControllerDelegate,
    ThemeChangeDelegate,
    URLDropDelegate> {
  // Helper object managing the availability of the voice search feature.
  VoiceSearchAvailability _voiceSearchAvailability;
}

@property(nonatomic, strong)
    ContentSuggestionsViewController* suggestionsViewController;
@property(nonatomic, strong)
    ContentSuggestionsMediator* contentSuggestionsMediator;
@property(nonatomic, strong)
    ContentSuggestionsHeaderSynchronizer* headerCollectionInteractionHandler;
@property(nonatomic, strong) ContentSuggestionsMetricsRecorder* metricsRecorder;
@property(nonatomic, strong) NTPHomeMediator* NTPMediator;
@property(nonatomic, strong) UIViewController* discoverFeedViewController;
@property(nonatomic, strong) URLDragDropHandler* dragDropHandler;
@property(nonatomic, strong) ActionSheetCoordinator* alertCoordinator;
// Redefined as readwrite.
@property(nonatomic, strong, readwrite)
    ContentSuggestionsHeaderViewController* headerController;
@property(nonatomic, strong) PrefBackedBoolean* contentSuggestionsVisible;

@end

@implementation ContentSuggestionsCoordinator

- (void)start {
  DCHECK(self.browser);
  if (self.visible) {
    // Prevent this coordinator from being started twice in a row
    return;
  }

  _visible = YES;

  ntp_snippets::ContentSuggestionsService* contentSuggestionsService =
      IOSChromeContentSuggestionsServiceFactory::GetForBrowserState(
          self.browser->GetBrowserState());
  contentSuggestionsService->remote_suggestions_scheduler()
      ->OnSuggestionsSurfaceOpened();
  contentSuggestionsService->user_classifier()->OnEvent(
      ntp_snippets::UserClassifier::Metric::NTP_OPENED);
  contentSuggestionsService->user_classifier()->OnEvent(
      ntp_snippets::UserClassifier::Metric::SUGGESTIONS_SHOWN);
  PrefService* prefs =
      ChromeBrowserState::FromBrowserState(self.browser->GetBrowserState())
          ->GetPrefs();
  bool contentSuggestionsEnabled =
      prefs->GetBoolean(prefs::kArticlesForYouEnabled);
  self.contentSuggestionsVisible = [[PrefBackedBoolean alloc]
      initWithPrefService:prefs
                 prefName:feed::prefs::kArticlesListVisible];
  if (contentSuggestionsEnabled) {
    if ([self.contentSuggestionsVisible value]) {
      ntp_home::RecordNTPImpression(ntp_home::REMOTE_SUGGESTIONS);
    } else {
      ntp_home::RecordNTPImpression(ntp_home::REMOTE_COLLAPSED);
    }
  } else {
    ntp_home::RecordNTPImpression(ntp_home::LOCAL_SUGGESTIONS);
  }

  self.NTPMediator = [[NTPHomeMediator alloc]
             initWithWebState:self.webState
           templateURLService:ios::TemplateURLServiceFactory::
                                  GetForBrowserState(
                                      self.browser->GetBrowserState())
                    URLLoader:UrlLoadingBrowserAgent::FromBrowser(self.browser)
                  authService:AuthenticationServiceFactory::GetForBrowserState(
                                  self.browser->GetBrowserState())
              identityManager:IdentityManagerFactory::GetForBrowserState(
                                  self.browser->GetBrowserState())
                   logoVendor:ios::GetChromeBrowserProvider()->CreateLogoVendor(
                                  self.browser, self.webState)
      voiceSearchAvailability:&_voiceSearchAvailability];
  self.NTPMediator.browser = self.browser;

  self.headerController = [[ContentSuggestionsHeaderViewController alloc] init];
  // TODO(crbug.com/1045047): Use HandlerForProtocol after commands protocol
  // clean up.
  self.headerController.dispatcher =
      static_cast<id<ApplicationCommands, BrowserCommands, OmniboxCommands,
                     FakeboxFocuser>>(self.browser->GetCommandDispatcher());
  self.headerController.commandHandler = self.NTPMediator;
  self.headerController.delegate = self.NTPMediator;
  self.headerController.readingListModel =
      ReadingListModelFactory::GetForBrowserState(
          self.browser->GetBrowserState());
  self.headerController.toolbarDelegate = self.toolbarDelegate;

  favicon::LargeIconService* largeIconService =
      IOSChromeLargeIconServiceFactory::GetForBrowserState(
          self.browser->GetBrowserState());
  LargeIconCache* cache = IOSChromeLargeIconCacheFactory::GetForBrowserState(
      self.browser->GetBrowserState());
  std::unique_ptr<ntp_tiles::MostVisitedSites> mostVisitedFactory =
      IOSMostVisitedSitesFactory::NewForBrowserState(
          self.browser->GetBrowserState());
  ReadingListModel* readingListModel =
      ReadingListModelFactory::GetForBrowserState(
          self.browser->GetBrowserState());

  self.discoverFeedViewController = ios::GetChromeBrowserProvider()
                                        ->GetDiscoverFeedProvider()
                                        ->NewFeedViewController(self.browser);

  // TODO(crbug.com/1085419): Once the CollectionView is cleanly exposed, remove
  // this loop.
  for (UIView* view in self.discoverFeedViewController.view.subviews) {
    if ([view isKindOfClass:[UICollectionView class]]) {
      UICollectionView* feedView = static_cast<UICollectionView*>(view);
      feedView.bounces = false;
      feedView.alwaysBounceVertical = false;
    }
  }

  self.contentSuggestionsMediator = [[ContentSuggestionsMediator alloc]
      initWithContentService:contentSuggestionsService
            largeIconService:largeIconService
              largeIconCache:cache
             mostVisitedSite:std::move(mostVisitedFactory)
            readingListModel:readingListModel
                 prefService:prefs
                discoverFeed:self.discoverFeedViewController];
  self.contentSuggestionsMediator.commandHandler = self.NTPMediator;
  self.contentSuggestionsMediator.headerProvider = self.headerController;
  self.contentSuggestionsMediator.contentArticlesExpanded =
      self.contentSuggestionsVisible;

  self.headerController.promoCanShow =
      [self.contentSuggestionsMediator notificationPromo]->CanShow();

  self.metricsRecorder = [[ContentSuggestionsMetricsRecorder alloc] init];
  self.metricsRecorder.delegate = self.contentSuggestionsMediator;

  self.suggestionsViewController = [[ContentSuggestionsViewController alloc]
      initWithStyle:CollectionViewControllerStyleDefault];
  [self.suggestionsViewController
      setDataSource:self.contentSuggestionsMediator];
  self.suggestionsViewController.suggestionCommandHandler = self.NTPMediator;
  self.suggestionsViewController.audience = self;
  self.suggestionsViewController.overscrollDelegate = self;
  self.suggestionsViewController.themeChangeDelegate = self;
  self.suggestionsViewController.metricsRecorder = self.metricsRecorder;
  id<SnackbarCommands> dispatcher = HandlerForProtocol(
      self.browser->GetCommandDispatcher(), SnackbarCommands);
  self.suggestionsViewController.dispatcher = dispatcher;
  self.suggestionsViewController.discoverFeedMenuHandler = self;

  if (@available(iOS 13.0, *)) {
    self.suggestionsViewController.menuProvider = self;
  }

  self.NTPMediator.consumer = self.headerController;
  // TODO(crbug.com/1045047): Use HandlerForProtocol after commands protocol
  // clean up.
  self.NTPMediator.dispatcher =
      static_cast<id<ApplicationCommands, BrowserCommands, OmniboxCommands,
                     SnackbarCommands>>(self.browser->GetCommandDispatcher());
  self.NTPMediator.NTPMetrics = [[NTPHomeMetrics alloc]
      initWithBrowserState:self.browser->GetBrowserState()
                  webState:self.webState];
  self.NTPMediator.metricsRecorder = self.metricsRecorder;
  self.NTPMediator.suggestionsViewController = self.suggestionsViewController;
  self.NTPMediator.suggestionsMediator = self.contentSuggestionsMediator;
  self.NTPMediator.suggestionsService = contentSuggestionsService;
  [self.NTPMediator setUp];

  [self.suggestionsViewController addChildViewController:self.headerController];
  [self.headerController
      didMoveToParentViewController:self.suggestionsViewController];

  self.headerCollectionInteractionHandler =
      [[ContentSuggestionsHeaderSynchronizer alloc]
          initWithCollectionController:self.suggestionsViewController
                      headerController:self.headerController];
  self.NTPMediator.headerCollectionInteractionHandler =
      self.headerCollectionInteractionHandler;

  if (DragAndDropIsEnabled()) {
    self.dragDropHandler = [[URLDragDropHandler alloc] init];
    self.dragDropHandler.dropDelegate = self;
    [self.suggestionsViewController.collectionView
        addInteraction:[[UIDropInteraction alloc]
                           initWithDelegate:self.dragDropHandler]];
  }
}

- (void)stop {
  [self.NTPMediator shutdown];
  self.NTPMediator = nil;
  [self.contentSuggestionsMediator disconnect];
  self.contentSuggestionsMediator = nil;
  self.headerController = nil;
  _visible = NO;
}

- (UIViewController*)viewController {
  return self.suggestionsViewController;
}

#pragma mark - ContentSuggestionsViewControllerAudience

- (void)promoShown {
  NotificationPromoWhatsNew* notificationPromo =
      [self.contentSuggestionsMediator notificationPromo];
  notificationPromo->HandleViewed();
  [self.headerController setPromoCanShow:notificationPromo->CanShow()];
}

#pragma mark - OverscrollActionsControllerDelegate

- (void)overscrollActionsController:(OverscrollActionsController*)controller
                   didTriggerAction:(OverscrollAction)action {
  // TODO(crbug.com/1045047): Use HandlerForProtocol after commands protocol
  // clean up.
  id<ApplicationCommands, BrowserCommands, OmniboxCommands, SnackbarCommands>
      handler = static_cast<id<ApplicationCommands, BrowserCommands,
                               OmniboxCommands, SnackbarCommands>>(
          self.browser->GetCommandDispatcher());
  switch (action) {
    case OverscrollAction::NEW_TAB: {
      [handler openURLInNewTab:[OpenNewTabCommand command]];
    } break;
    case OverscrollAction::CLOSE_TAB: {
      [handler closeCurrentTab];
      base::RecordAction(base::UserMetricsAction("OverscrollActionCloseTab"));
    } break;
    case OverscrollAction::REFRESH:
      [self reload];
      break;
    case OverscrollAction::NONE:
      NOTREACHED();
      break;
  }
}

- (BOOL)shouldAllowOverscrollActionsForOverscrollActionsController:
    (OverscrollActionsController*)controller {
  return YES;
}

- (UIView*)toolbarSnapshotViewForOverscrollActionsController:
    (OverscrollActionsController*)controller {
  return
      [[self.headerController toolBarView] snapshotViewAfterScreenUpdates:NO];
}

- (UIView*)headerViewForOverscrollActionsController:
    (OverscrollActionsController*)controller {
  return self.suggestionsViewController.view;
}

- (CGFloat)headerInsetForOverscrollActionsController:
    (OverscrollActionsController*)controller {
  return 0;
}

- (CGFloat)headerHeightForOverscrollActionsController:
    (OverscrollActionsController*)controller {
  CGFloat height = [self.headerController toolBarView].bounds.size.height;
  CGFloat topInset = self.suggestionsViewController.view.safeAreaInsets.top;
  return height + topInset;
}

- (FullscreenController*)fullscreenControllerForOverscrollActionsController:
    (OverscrollActionsController*)controller {
  // Fullscreen isn't supported here.
  return nullptr;
}

#pragma mark - ThemeChangeDelegate

- (void)handleThemeChange {
  if (IsDiscoverFeedEnabled()) {
    ios::GetChromeBrowserProvider()->GetDiscoverFeedProvider()->UpdateTheme();
  }
}

#pragma mark - URLDropDelegate

- (BOOL)canHandleURLDropInView:(UIView*)view {
  return YES;
}

- (void)view:(UIView*)view didDropURL:(const GURL&)URL atPoint:(CGPoint)point {
  UrlLoadingBrowserAgent::FromBrowser(self.browser)
      ->Load(UrlLoadParams::InCurrentTab(URL));
}

#pragma mark - DiscoverFeedMenuCommands

- (void)openDiscoverFeedMenu:(UIView*)menuButton {
  [self.alertCoordinator stop];
  self.alertCoordinator = nil;

  self.alertCoordinator = [[ActionSheetCoordinator alloc]
      initWithBaseViewController:self.suggestionsViewController
                         browser:self.browser
                           title:nil
                         message:nil
                            rect:menuButton.frame
                            view:menuButton.superview];
  __weak ContentSuggestionsCoordinator* weakSelf = self;

  if ([self.contentSuggestionsVisible value]) {
    [self.alertCoordinator
        addItemWithTitle:l10n_util::GetNSString(
                             IDS_IOS_DISCOVER_FEED_MENU_TURN_OFF_ITEM)
                  action:^{
                    [weakSelf.contentSuggestionsVisible setValue:NO];
                    [weakSelf.contentSuggestionsMediator reloadAllData];
                  }
                   style:UIAlertActionStyleDestructive];
  } else {
    [self.alertCoordinator
        addItemWithTitle:l10n_util::GetNSString(
                             IDS_IOS_DISCOVER_FEED_MENU_TURN_ON_ITEM)
                  action:^{
                    [weakSelf.contentSuggestionsVisible setValue:YES];
                    [weakSelf.contentSuggestionsMediator reloadAllData];
                  }
                   style:UIAlertActionStyleDefault];
  }

  [self.alertCoordinator
      addItemWithTitle:l10n_util::GetNSString(
                           IDS_IOS_DISCOVER_FEED_MENU_MANAGE_INTERESTS_ITEM)
                action:^{
                  [weakSelf.NTPMediator handleManageInterestsTapped];
                }
                 style:UIAlertActionStyleDefault];

  [self.alertCoordinator
      addItemWithTitle:l10n_util::GetNSString(
                           IDS_IOS_DISCOVER_FEED_MENU_LEARN_MORE_ITEM)
                action:^{
                  [weakSelf.NTPMediator handleLearnMoreTapped];
                }
                 style:UIAlertActionStyleDefault];
  [self.alertCoordinator start];
}

#pragma mark - Public methods

- (UIView*)view {
  return self.suggestionsViewController.view;
}

- (void)dismissModals {
  [self.NTPMediator dismissModals];
}

- (UIEdgeInsets)contentInset {
  return self.suggestionsViewController.collectionView.contentInset;
}

- (CGPoint)contentOffset {
  CGPoint collectionOffset =
      self.suggestionsViewController.collectionView.contentOffset;
  collectionOffset.y -=
      self.headerCollectionInteractionHandler.collectionShiftingOffset;
  return collectionOffset;
}

- (void)willUpdateSnapshot {
  [self.suggestionsViewController clearOverscroll];
}

- (void)reload {
  [self.contentSuggestionsMediator.dataSink reloadAllData];
}

- (void)locationBarDidBecomeFirstResponder {
  [self.NTPMediator locationBarDidBecomeFirstResponder];
}
- (void)locationBarDidResignFirstResponder {
  [self.NTPMediator locationBarDidResignFirstResponder];
}

#pragma mark - ThemeChangeDelegate

- (UIContextMenuConfiguration*)contextMenuConfigurationForItem:
    (ContentSuggestionsMostVisitedItem*)item API_AVAILABLE(ios(13.0)) {
  return [UIContextMenuConfiguration
      configurationWithIdentifier:nil
                  previewProvider:nil
                   actionProvider:^(NSArray<UIMenuElement*>* suggestedActions) {
                     // Record that this context menu was shown to the user.
                     RecordMenuShown(MenuScenario::kContentSuggestionsEntry);

                     ActionFactory* actionFactory = [[ActionFactory alloc]
                         initWithScenario:MenuScenario::
                                              kContentSuggestionsEntry];

                     UIAction* copyAction =
                         [actionFactory actionToCopyURL:item.URL];

                     return [UIMenu menuWithTitle:@"" children:@[ copyAction ]];
                   }];
}

@end
