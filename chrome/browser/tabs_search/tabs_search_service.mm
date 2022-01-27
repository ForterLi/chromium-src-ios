// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/tabs_search/tabs_search_service.h"

#import <Foundation/Foundation.h>

#include "base/i18n/break_iterator.h"
#include "base/i18n/string_search.h"
#import "base/strings/sys_string_conversions.h"
#import "base/strings/utf_string_conversions.h"
#include "components/keyed_service/core/service_access_type.h"
#include "components/sessions/core/tab_restore_service.h"
#include "components/signin/public/base/consent_level.h"
#include "components/signin/public/identity_manager/identity_manager.h"
#include "components/sync_sessions/session_sync_service.h"
#include "ios/chrome/browser/history/history_service_factory.h"
#include "ios/chrome/browser/history/history_utils.h"
#include "ios/chrome/browser/history/web_history_service_factory.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/main/browser_list.h"
#include "ios/chrome/browser/sessions/ios_chrome_tab_restore_service_factory.h"
#include "ios/chrome/browser/signin/identity_manager_factory.h"
#include "ios/chrome/browser/sync/session_sync_service_factory.h"
#include "ios/chrome/browser/sync/sync_service_factory.h"
#import "ios/chrome/browser/tabs/tab_title_util.h"
#include "ios/chrome/browser/ui/recent_tabs/synced_sessions.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/web/public/web_state.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using base::i18n::FixedPatternStringSearchIgnoringCaseAndAccents;

TabsSearchService::TabsSearchService(ChromeBrowserState* browser_state,
                                     BrowserList* browser_list)
    : browser_state_(browser_state), browser_list_(browser_list) {
  DCHECK(browser_state_);
  DCHECK(browser_list_);
}

TabsSearchService::~TabsSearchService() = default;

void TabsSearchService::Search(
    const std::u16string& term,
    base::OnceCallback<void(std::vector<web::WebState*>)> completion) {
  SearchWithinBrowsers(browser_list_->AllRegularBrowsers(), term,
                       std::move(completion));
}

void TabsSearchService::SearchIncognito(
    const std::u16string& term,
    base::OnceCallback<void(std::vector<web::WebState*>)> completion) {
  SearchWithinBrowsers(browser_list_->AllIncognitoBrowsers(), term,
                       std::move(completion));
}

void TabsSearchService::SearchRecentlyClosed(
    const std::u16string& term,
    base::OnceCallback<void(
        std::vector<const sessions::SerializedNavigationEntry>)> completion) {
  FixedPatternStringSearchIgnoringCaseAndAccents query_search(term);

  std::vector<const sessions::SerializedNavigationEntry> results;
  sessions::TabRestoreService* restore_service =
      IOSChromeTabRestoreServiceFactory::GetForBrowserState(browser_state_);
  for (auto iter = restore_service->entries().begin();
       iter != restore_service->entries().end(); ++iter) {
    const sessions::TabRestoreService::Entry* entry = iter->get();
    DCHECK(entry);
    DCHECK_EQ(sessions::TabRestoreService::TAB, entry->type);
    const sessions::TabRestoreService::Tab* tab =
        static_cast<const sessions::TabRestoreService::Tab*>(entry);
    const sessions::SerializedNavigationEntry& navigationEntry =
        tab->navigations[tab->current_navigation_index];

    if (query_search.Search(navigationEntry.title(), /*match_index=*/nullptr,
                            /*match_length=*/nullptr) ||
        query_search.Search(
            base::UTF8ToUTF16(navigationEntry.virtual_url().spec()),
            /*match_index=*/nullptr, nullptr)) {
      results.push_back(navigationEntry);
    }
  }

  std::move(completion).Run(results);
}

void TabsSearchService::SearchRemoteTabs(
    const std::u16string& term,
    base::OnceCallback<void(std::vector<synced_sessions::DistantTab*>)>
        completion) {
  std::vector<synced_sessions::DistantTab*> results;

  signin::IdentityManager* identity_manager =
      IdentityManagerFactory::GetForBrowserState(browser_state_);
  if (!identity_manager->HasPrimaryAccount(signin::ConsentLevel::kSignin)) {
    // There must be a primary account for synced sessions to be available.
    std::move(completion).Run(results);
    return;
  }

  FixedPatternStringSearchIgnoringCaseAndAccents query_search(term);
  sync_sessions::SessionSyncService* sync_service =
      SessionSyncServiceFactory::GetForBrowserState(browser_state_);
  synced_sessions::SyncedSessions synced_sessions(sync_service);

  for (size_t s = 0; s < synced_sessions.GetSessionCount(); s++) {
    const synced_sessions::DistantSession* session =
        synced_sessions.GetSession(s);
    for (auto&& distant_tab : session->tabs) {
      if (query_search.Search(distant_tab->title, /*match_index=*/nullptr,
                              /*match_length=*/nullptr) ||
          query_search.Search(
              base::UTF8ToUTF16(distant_tab->virtual_url.spec()),
              /*match_index=*/nullptr, nullptr)) {
        results.push_back(distant_tab.get());
      }
    }
  }

  std::move(completion).Run(results);
}

void TabsSearchService::SearchHistory(
    const std::u16string& term,
    base::OnceCallback<void(size_t result_count)> completion) {
  DCHECK(completion);

  ongoing_history_search_term_ = term;
  history_search_callback_ = std::move(completion);

  history_driver_ =
      std::make_unique<IOSBrowsingHistoryDriver>(browser_state_, this);

  history_service_ = std::make_unique<history::BrowsingHistoryService>(
      history_driver_.get(),
      ios::HistoryServiceFactory::GetForBrowserState(
          browser_state_, ServiceAccessType::EXPLICIT_ACCESS),
      SyncServiceFactory::GetForBrowserState(browser_state_));

  history::QueryOptions options;
  options.duplicate_policy = history::QueryOptions::REMOVE_ALL_DUPLICATES;
  options.matching_algorithm =
      query_parser::MatchingAlgorithm::ALWAYS_PREFIX_SEARCH;
  history_service_->QueryHistory(term, options);
}

#pragma mark - Private

void TabsSearchService::SearchWithinBrowsers(
    const std::set<Browser*>& browsers,
    const std::u16string& term,
    base::OnceCallback<void(std::vector<web::WebState*>)> completion) {
  FixedPatternStringSearchIgnoringCaseAndAccents query_search(term);

  std::vector<web::WebState*> results;

  for (Browser* browser : browsers) {
    WebStateList* webStateList = browser->GetWebStateList();
    for (int index = 0; index < webStateList->count(); ++index) {
      web::WebState* web_state = webStateList->GetWebStateAt(index);
      auto title = base::SysNSStringToUTF16(tab_util::GetTabTitle(web_state));
      auto url_string = base::UTF8ToUTF16(web_state->GetVisibleURL().spec());
      if (query_search.Search(title, /*match_index=*/nullptr,
                              /*match_length=*/nullptr) ||
          query_search.Search(url_string, /*match_index=*/nullptr, nullptr)) {
        results.push_back(web_state);
      }
    }
  }

  std::move(completion).Run(results);
}

#pragma mark history::BrowsingHistoryDriver

void TabsSearchService::HistoryQueryCompleted(
    const std::vector<history::BrowsingHistoryService::HistoryEntry>& results,
    const history::BrowsingHistoryService::QueryResultsInfo& query_results_info,
    base::OnceClosure continuation_closure) {
  if (!history_search_callback_) {
    return;
  }

  if (query_results_info.search_text != ongoing_history_search_term_) {
    // This is an old search, ignore results.
    return;
  }

  std::move(history_search_callback_).Run(results.size());

  ongoing_history_search_term_ = nullptr;
  history_service_.reset();
}
