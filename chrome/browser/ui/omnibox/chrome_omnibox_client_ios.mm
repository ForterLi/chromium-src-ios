// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/ui/omnibox/chrome_omnibox_client_ios.h"

#include "base/strings/string_util.h"
#include "base/strings/utf_string_conversions.h"
#include "base/task/post_task.h"
#include "base/task/thread_pool.h"
#include "components/favicon/ios/web_favicon_driver.h"
#include "components/omnibox/browser/autocomplete_match.h"
#include "components/omnibox/browser/autocomplete_result.h"
#include "components/omnibox/browser/omnibox_edit_controller.h"
#include "components/omnibox/browser/omnibox_log.h"
#include "components/search_engines/template_url_service.h"
#include "ios/chrome/browser/autocomplete/autocomplete_classifier_factory.h"
#include "ios/chrome/browser/autocomplete/autocomplete_provider_client_impl.h"
#include "ios/chrome/browser/bookmarks/bookmark_model_factory.h"
#include "ios/chrome/browser/bookmarks/bookmarks_utils.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#include "ios/chrome/browser/prerender/prerender_service.h"
#include "ios/chrome/browser/prerender/prerender_service_factory.h"
#include "ios/chrome/browser/search_engines/template_url_service_factory.h"
#include "ios/chrome/browser/sessions/ios_chrome_session_tab_helper.h"
#include "ios/chrome/browser/ui/omnibox/web_omnibox_edit_controller.h"
#include "ios/chrome/common/intents/SearchInChromeIntent.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/web/public/navigation/navigation_manager.h"
#import "ios/web/public/web_state.h"
#include "ui/base/l10n/l10n_util.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

ChromeOmniboxClientIOS::ChromeOmniboxClientIOS(
    WebOmniboxEditController* controller,
    ChromeBrowserState* browser_state)
    : controller_(controller), browser_state_(browser_state) {}

ChromeOmniboxClientIOS::~ChromeOmniboxClientIOS() {}

std::unique_ptr<AutocompleteProviderClient>
ChromeOmniboxClientIOS::CreateAutocompleteProviderClient() {
  return std::make_unique<AutocompleteProviderClientImpl>(browser_state_);
}

bool ChromeOmniboxClientIOS::CurrentPageExists() const {
  return (controller_->GetWebState() != nullptr);
}

const GURL& ChromeOmniboxClientIOS::GetURL() const {
  return CurrentPageExists() ? controller_->GetWebState()->GetVisibleURL()
                             : GURL::EmptyGURL();
}

bool ChromeOmniboxClientIOS::IsLoading() const {
  return controller_->GetWebState()->IsLoading();
}

bool ChromeOmniboxClientIOS::IsPasteAndGoEnabled() const {
  return false;
}

bool ChromeOmniboxClientIOS::IsDefaultSearchProviderEnabled() const {
  // iOS does not have Enterprise policies
  return true;
}

const SessionID& ChromeOmniboxClientIOS::GetSessionID() const {
  return IOSChromeSessionTabHelper::FromWebState(controller_->GetWebState())
      ->session_id();
}

bookmarks::BookmarkModel* ChromeOmniboxClientIOS::GetBookmarkModel() {
  return ios::BookmarkModelFactory::GetForBrowserState(browser_state_);
}

TemplateURLService* ChromeOmniboxClientIOS::GetTemplateURLService() {
  return ios::TemplateURLServiceFactory::GetForBrowserState(browser_state_);
}

const AutocompleteSchemeClassifier&
ChromeOmniboxClientIOS::GetSchemeClassifier() const {
  return scheme_classifier_;
}

AutocompleteClassifier* ChromeOmniboxClientIOS::GetAutocompleteClassifier() {
  return ios::AutocompleteClassifierFactory::GetForBrowserState(browser_state_);
}

bool ChromeOmniboxClientIOS::ShouldDefaultTypedNavigationsToHttps() const {
  // Defaulting omnibox navigations to HTTPS not yet supported on iOS.
  return false;
}

int ChromeOmniboxClientIOS::GetHttpsPortForTesting() const {
  return 0;
}

gfx::Image ChromeOmniboxClientIOS::GetIconIfExtensionMatch(
    const AutocompleteMatch& match) const {
  // Extensions are not supported on iOS.
  return gfx::Image();
}

bool ChromeOmniboxClientIOS::ProcessExtensionKeyword(
    const std::u16string& text,
    const TemplateURL* template_url,
    const AutocompleteMatch& match,
    WindowOpenDisposition disposition) {
  // Extensions are not supported on iOS.
  return false;
}

void ChromeOmniboxClientIOS::OnFocusChanged(OmniboxFocusState state,
                                            OmniboxFocusChangeReason reason) {
  // TODO(crbug.com/754050): OnFocusChanged is not the correct place to be
  // canceling prerenders, but this is the closest match to the original
  // location of this code, which was in OmniboxViewIOS::OnDidEndEditing().  The
  // goal of this code is to cancel prerenders when the omnibox loses focus.
  // Otherwise, they will live forever in cases where the user navigates to a
  // different URL than what is prerendered.
  if (state == OMNIBOX_FOCUS_NONE) {
    PrerenderService* service =
        PrerenderServiceFactory::GetForBrowserState(browser_state_);
    if (service) {
      service->CancelPrerender();
    }
  }
}

void ChromeOmniboxClientIOS::OnResultChanged(
    const AutocompleteResult& result,
    bool default_match_changed,
    bool should_prerender,
    const BitmapFetchedCallback& on_bitmap_fetched) {
  if (result.empty()) {
    return;
  }

  PrerenderService* service =
      PrerenderServiceFactory::GetForBrowserState(browser_state_);
  if (!service) {
    return;
  }

  const AutocompleteMatch& match = result.match_at(0);
  bool is_inline_autocomplete = !match.inline_autocompletion.empty();

  // TODO(crbug.com/228480): When prerendering the result of a paste
  // operation, we should change the transition to LINK instead of TYPED.

  // Only prerender HISTORY_URL matches, which come from the history DB.  Do
  // not prerender other types of matches, including matches from the search
  // provider.
  if (is_inline_autocomplete &&
      match.type == AutocompleteMatchType::HISTORY_URL) {
    ui::PageTransition transition = ui::PageTransitionFromInt(
        match.transition | ui::PAGE_TRANSITION_FROM_ADDRESS_BAR);
    service->StartPrerender(match.destination_url, web::Referrer(), transition,
                            controller_->GetWebState(), is_inline_autocomplete);
  } else {
    service->CancelPrerender();
  }
}

void ChromeOmniboxClientIOS::OnURLOpenedFromOmnibox(OmniboxLog* log) {
  // If a search was done, donate the Search In Chrome intent to the OS for
  // future Siri suggestions.
  if (!browser_state_->IsOffTheRecord() &&
      (log->input_type == metrics::OmniboxInputType::QUERY ||
       log->input_type == metrics::OmniboxInputType::UNKNOWN)) {
    base::ThreadPool::PostTask(
        FROM_HERE, {base::MayBlock(), base::TaskPriority::BEST_EFFORT},
        base::BindOnce(^{
          SearchInChromeIntent* searchInChromeIntent =
              [[SearchInChromeIntent alloc] init];

          // SiriKit requires the intent parameter to be set to a non-empty
          // string in order to accept the intent donation. Set it to a single
          // space, to be later trimmed by the intent handler, which will result
          // in the shortcut being treated as if no search phrase was supplied.
          searchInChromeIntent.searchPhrase = @" ";
          searchInChromeIntent.suggestedInvocationPhrase =
              l10n_util::GetNSString(
                  IDS_IOS_INTENTS_SEARCH_IN_CHROME_INVOCATION_PHRASE);
          INInteraction* interaction =
              [[INInteraction alloc] initWithIntent:searchInChromeIntent
                                           response:nil];
          [interaction donateInteractionWithCompletion:nil];
        }));
  }
}

void ChromeOmniboxClientIOS::DiscardNonCommittedNavigations() {
  controller_->GetWebState()
      ->GetNavigationManager()
      ->DiscardNonCommittedItems();
}

const std::u16string& ChromeOmniboxClientIOS::GetTitle() const {
  return CurrentPageExists() ? controller_->GetWebState()->GetTitle()
                             : base::EmptyString16();
}

gfx::Image ChromeOmniboxClientIOS::GetFavicon() const {
  return favicon::WebFaviconDriver::FromWebState(controller_->GetWebState())
      ->GetFavicon();
}
