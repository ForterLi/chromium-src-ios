// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <memory>
#include <string>

#include "base/base_paths.h"
#include "base/bind.h"
#include "base/files/file_path.h"
#include "base/ios/ios_util.h"
#import "base/ios/ns_error_util.h"
#include "base/mac/foundation_util.h"
#include "base/path_service.h"
#include "base/scoped_observation.h"
#include "base/strings/sys_string_conversions.h"
#include "base/strings/utf_string_conversions.h"
#include "base/test/gmock_callback_support.h"
#import "base/test/ios/wait_util.h"
#include "base/test/scoped_feature_list.h"
#import "ios/net/protocol_handler_util.h"
#include "ios/testing/embedded_test_server_handlers.h"
#include "ios/web/common/features.h"
#include "ios/web/navigation/wk_navigation_util.h"
#import "ios/web/public/navigation/navigation_context.h"
#import "ios/web/public/navigation/navigation_item.h"
#import "ios/web/public/navigation/navigation_manager.h"
#import "ios/web/public/navigation/web_state_policy_decider.h"
#import "ios/web/public/session/crw_navigation_item_storage.h"
#import "ios/web/public/session/crw_session_storage.h"
#import "ios/web/public/test/error_test_util.h"
#import "ios/web/public/test/fakes/async_web_state_policy_decider.h"
#import "ios/web/public/test/fakes/fake_web_client.h"
#include "ios/web/public/test/fakes/fake_web_state_observer.h"
#import "ios/web/public/test/navigation_test_util.h"
#import "ios/web/public/test/web_view_content_test_util.h"
#import "ios/web/public/test/web_view_interaction_test_util.h"
#import "ios/web/public/web_client.h"
#include "ios/web/public/web_state_observer.h"
#include "ios/web/test/test_url_constants.h"
#import "ios/web/test/web_int_test.h"
#import "ios/web/web_state/ui/crw_web_controller.h"
#import "ios/web/web_state/web_state_impl.h"
#import "net/base/mac/url_conversions.h"
#import "net/base/net_errors.h"
#include "net/http/http_response_headers.h"
#include "net/test/embedded_test_server/default_handlers.h"
#include "net/test/embedded_test_server/embedded_test_server.h"
#include "net/test/embedded_test_server/http_request.h"
#include "net/test/embedded_test_server/http_response.h"
#include "net/test/embedded_test_server/request_handler_util.h"
#include "testing/gmock/include/gmock/gmock.h"
#include "testing/gtest/include/gtest/gtest.h"
#import "testing/gtest_mac.h"
#include "ui/base/page_transition_types.h"
#include "url/gurl.h"
#include "url/scheme_host_port.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace web {

namespace {

using base::test::RunOnceCallback;
using wk_navigation_util::CreateRedirectUrl;
using ::testing::WithArgs;

const char kExpectedMimeType[] = "text/html";

const char16_t kFailedTitle[] = u"failed_title";

// Location of a test page.
const char kTestPageURL[] = "/pony.html";

// A text string from the test HTML page at |kTestPageURL|.
const char kTestSessionStoragePageText[] = "pony";

// Returns a session storage with a single committed entry of a test HTML page.
CRWSessionStorage* GetTestSessionStorage(const GURL& testUrl) {
  CRWSessionStorage* result = [[CRWSessionStorage alloc] init];
  result.lastCommittedItemIndex = 0;
  CRWNavigationItemStorage* item = [[CRWNavigationItemStorage alloc] init];
  [item setURL:testUrl];
  [result setItemStorages:@[ item ]];
  result.userAgentType = UserAgentType::MOBILE;
  return result;
}

// Calls Stop() on the given WebState and returns a PolicyDecision which
// allows the request to continue.
ACTION_P(ReturnAllowRequestAndStopNavigation, web_state) {
  dispatch_async(dispatch_get_main_queue(), ^{
    web_state->Stop();
  });
  base::ThreadTaskRunnerHandle::Get()->PostTask(
      FROM_HERE,
      base::BindOnce(std::move(arg0),
                     WebStatePolicyDecider::PolicyDecision::Allow()));
}

// Verifies correctness of WebState's title.
ACTION_P(VerifyTitle, expected_title) {
  WebState* web_state = arg0;
  EXPECT_EQ(expected_title, base::UTF16ToASCII(web_state->GetTitle()));
}

// Verifies correctness of |NavigationContext| (|arg1|) for new page navigation
// passed to |DidStartNavigation|. Stores |NavigationContext| in |context|
// pointer.
ACTION_P5(VerifyPageStartedContext,
          web_state,
          url,
          transition,
          context,
          nav_id) {
  *context = arg1;
  ASSERT_TRUE(*context);
  EXPECT_EQ(web_state, arg0);
  EXPECT_EQ(web_state, (*context)->GetWebState());
  *nav_id = (*context)->GetNavigationId();
  EXPECT_NE(0, *nav_id);
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  ui::PageTransition actual_transition = (*context)->GetPageTransition();
  EXPECT_TRUE(PageTransitionCoreTypeIs(transition, actual_transition))
      << "Got unexpected transition: " << actual_transition;
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
  ASSERT_FALSE((*context)->GetResponseHeaders());
  ASSERT_TRUE(web_state->IsLoading());
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetPendingItem();
  EXPECT_EQ(url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for new page navigation
// passed to |DidStartNavigation|. Stores |NavigationContext| in |context|
// pointer. This action is used to verify one of multiple pending navigations.
ACTION_P6(VerifyPageConcurrentlyStartedContext,
          web_state,
          context_url,
          item_url,
          transition,
          context,
          nav_id) {
  *context = arg1;
  ASSERT_TRUE(*context);
  EXPECT_EQ(web_state, arg0);
  EXPECT_EQ(web_state, (*context)->GetWebState());
  *nav_id = (*context)->GetNavigationId();
  EXPECT_NE(0, *nav_id);
  EXPECT_EQ(context_url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  ui::PageTransition actual_transition = (*context)->GetPageTransition();
  EXPECT_TRUE(PageTransitionCoreTypeIs(transition, actual_transition))
      << "Got unexpected transition: " << actual_transition;
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
  ASSERT_FALSE((*context)->GetResponseHeaders());
  ASSERT_TRUE(web_state->IsLoading());
  // GetPendingItem() returns last pending item. Not item associated with
  // the given navigation context.
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetPendingItem();
  EXPECT_EQ(item_url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for data navigation
// passed to |DidStartNavigation|. Stores |NavigationContext| in |context|
// pointer.
ACTION_P5(VerifyDataStartedContext,
          web_state,
          url,
          transition,
          context,
          nav_id) {
  *context = arg1;
  ASSERT_TRUE(*context);
  EXPECT_EQ(web_state, arg0);
  EXPECT_EQ(web_state, (*context)->GetWebState());
  *nav_id = (*context)->GetNavigationId();
  EXPECT_NE(0, *nav_id);
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  ui::PageTransition actual_transition = (*context)->GetPageTransition();
  EXPECT_TRUE(PageTransitionCoreTypeIs(transition, actual_transition))
      << "Got unexpected transition: " << actual_transition;
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
  ASSERT_FALSE((*context)->GetResponseHeaders());
  EXPECT_TRUE(web_state->IsLoading());
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetLastCommittedItem();
  EXPECT_EQ(url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for navigation for
// stopped load. Stores |NavigationContext| in |context| pointer.
ACTION_P5(VerifyAbortedNavigationStartedContext,
          web_state,
          url,
          transition,
          context,
          nav_id) {
  *context = arg1;
  ASSERT_TRUE(*context);
  EXPECT_EQ(web_state, arg0);
  EXPECT_EQ(web_state, (*context)->GetWebState());
  *nav_id = (*context)->GetNavigationId();
  EXPECT_NE(0, *nav_id);
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  ui::PageTransition actual_transition = (*context)->GetPageTransition();
  EXPECT_TRUE(PageTransitionCoreTypeIs(transition, actual_transition))
      << "Got unexpected transition: " << actual_transition;
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
  EXPECT_FALSE((*context)->GetResponseHeaders());
  EXPECT_FALSE(web_state->IsLoading());
  // Pending Item was removed by Stop call (see crbug.com/969915).
  EXPECT_FALSE(web_state->GetNavigationManager()->GetPendingItem());
}

// Verifies correctness of |NavigationContext| (|arg1|) for new page navigation
// passed to |DidFinishNavigation|. Asserts that |NavigationContext| the same as
// |context|.
ACTION_P6(VerifyNewPageFinishedContext,
          web_state,
          url,
          mime_type,
          content_is_html,
          context,
          nav_id) {
  ASSERT_EQ(*context, arg1);
  EXPECT_EQ(web_state, arg0);
  ASSERT_TRUE((*context));
  EXPECT_EQ(web_state, (*context)->GetWebState());
  EXPECT_EQ(*nav_id, (*context)->GetNavigationId());
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  EXPECT_TRUE(
      PageTransitionCoreTypeIs(ui::PageTransition::PAGE_TRANSITION_TYPED,
                               (*context)->GetPageTransition()));
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_TRUE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
  if (!url.SchemeIs(url::kAboutScheme)) {
    ASSERT_TRUE((*context)->GetResponseHeaders());
    std::string actual_mime_type;
    (*context)->GetResponseHeaders()->GetMimeType(&actual_mime_type);
    EXPECT_EQ(mime_type, actual_mime_type);
    EXPECT_EQ(mime_type, actual_mime_type);
  }
  ASSERT_TRUE(web_state->IsLoading());
  ASSERT_EQ(content_is_html, web_state->ContentIsHTML());
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetLastCommittedItem();
  EXPECT_TRUE(!item->GetTimestamp().is_null());
  EXPECT_EQ(url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for file:// URL
// navigation passed to |DidFinishNavigation|. Asserts that |NavigationContext|
// the same as |context|.
ACTION_P4(VerifyPdfFileUrlFinishedContext, web_state, url, context, nav_id) {
  ASSERT_EQ(*context, arg1);
  EXPECT_EQ(web_state, arg0);
  ASSERT_TRUE((*context));
  EXPECT_EQ(web_state, (*context)->GetWebState());
  EXPECT_EQ(*nav_id, (*context)->GetNavigationId());
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  EXPECT_TRUE(
      PageTransitionCoreTypeIs(ui::PageTransition::PAGE_TRANSITION_TYPED,
                               (*context)->GetPageTransition()));
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_TRUE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
  ASSERT_FALSE((*context)->GetResponseHeaders());
  ASSERT_TRUE(web_state->IsLoading());
  ASSERT_FALSE(web_state->ContentIsHTML());
  ASSERT_EQ("application/pdf", web_state->GetContentsMimeType());
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetLastCommittedItem();
  EXPECT_TRUE(!item->GetTimestamp().is_null());
  EXPECT_EQ(url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for data navigation
// passed to |DidFinishNavigation|. Asserts that |NavigationContext| the same as
// |context|.
ACTION_P5(VerifyDataFinishedContext,
          web_state,
          url,
          mime_type,
          context,
          nav_id) {
  ASSERT_EQ(*context, arg1);
  EXPECT_EQ(web_state, arg0);
  ASSERT_TRUE((*context));
  EXPECT_EQ(web_state, (*context)->GetWebState());
  EXPECT_EQ(*nav_id, (*context)->GetNavigationId());
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  EXPECT_TRUE(
      PageTransitionCoreTypeIs(ui::PageTransition::PAGE_TRANSITION_TYPED,
                               (*context)->GetPageTransition()));
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
  EXPECT_FALSE((*context)->GetResponseHeaders());
  EXPECT_TRUE(web_state->ContentIsHTML());
  EXPECT_EQ(mime_type, web_state->GetContentsMimeType());
  EXPECT_TRUE(web_state->IsLoading());
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetLastCommittedItem();
  EXPECT_TRUE(!item->GetTimestamp().is_null());
  EXPECT_EQ(url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for failed navigation
// passed to |DidFinishNavigation|. Asserts that |NavigationContext| the same as
// |context|.
ACTION_P6(VerifyErrorFinishedContext,
          web_state,
          url,
          context,
          nav_id,
          committed,
          net_error_code) {
  ASSERT_EQ(*context, arg1);
  EXPECT_EQ(web_state, arg0);
  ASSERT_TRUE((*context));
  EXPECT_EQ(web_state, (*context)->GetWebState());
  EXPECT_EQ(*nav_id, (*context)->GetNavigationId());
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  EXPECT_TRUE(
      PageTransitionCoreTypeIs(ui::PageTransition::PAGE_TRANSITION_TYPED,
                               (*context)->GetPageTransition()));
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_EQ(committed, (*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  // The error code will be different on bots and for local runs. Allow both.
  NSError* error =
      base::ios::GetFinalUnderlyingErrorFromError((*context)->GetError());
  EXPECT_EQ(net_error_code, error.code);
  EXPECT_FALSE((*context)->IsRendererInitiated());
  EXPECT_FALSE((*context)->GetResponseHeaders());
  ASSERT_TRUE(!web_state->IsLoading());
  ASSERT_FALSE(web_state->ContentIsHTML());
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetLastCommittedItem();
  if (committed) {
    ASSERT_TRUE(item);
    EXPECT_FALSE(item->GetTimestamp().is_null());
    EXPECT_EQ(url, item->GetURL());
  } else {
    EXPECT_FALSE(item);
  }
}

// Verifies correctness of |NavigationContext| (|arg1|) passed to
// |DidFinishNavigation| for navigation canceled due to a rejected response.
// Asserts that |NavigationContext| the same as |context|.
ACTION_P4(VerifyResponseRejectedFinishedContext,
          web_state,
          url,
          context,
          nav_id) {
  ASSERT_EQ(*context, arg1);
  EXPECT_EQ(web_state, arg0);
  ASSERT_TRUE((*context));
  EXPECT_EQ(web_state, (*context)->GetWebState());
  EXPECT_EQ(*nav_id, (*context)->GetNavigationId());
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  EXPECT_TRUE(
      PageTransitionCoreTypeIs(ui::PageTransition::PAGE_TRANSITION_TYPED,
                               (*context)->GetPageTransition()));
  EXPECT_FALSE((*context)->IsSameDocument());
  // When the response is rejected discard non committed items is called and
  // no item should be committed.
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
  EXPECT_FALSE((*context)->GetResponseHeaders());
  ASSERT_FALSE(web_state->IsLoading());
  ASSERT_FALSE(web_state->ContentIsHTML());
}

// Verifies correctness of |NavigationContext| (|arg1|) for navigations via POST
// HTTP methods passed to |DidStartNavigation|. Stores |NavigationContext| in
// |context| pointer.
ACTION_P6(VerifyPostStartedContext,
          web_state,
          url,
          has_user_gesture,
          context,
          nav_id,
          renderer_initiated) {
  *context = arg1;
  ASSERT_TRUE(*context);
  EXPECT_EQ(web_state, arg0);
  EXPECT_EQ(web_state, (*context)->GetWebState());
  *nav_id = (*context)->GetNavigationId();
  EXPECT_NE(0, *nav_id);
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_EQ(has_user_gesture, (*context)->HasUserGesture());
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_TRUE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_EQ(renderer_initiated, (*context)->IsRendererInitiated());
  ASSERT_FALSE((*context)->GetResponseHeaders());
  ASSERT_TRUE(web_state->IsLoading());
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetPendingItem();
  EXPECT_EQ(url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for navigations via POST
// HTTP methods passed to |DidFinishNavigation|. Stores |NavigationContext| in
// |context| pointer.
ACTION_P6(VerifyPostFinishedContext,
          web_state,
          url,
          has_user_gesture,
          context,
          nav_id,
          renderer_initiated) {
  ASSERT_EQ(*context, arg1);
  EXPECT_EQ(web_state, arg0);
  ASSERT_TRUE((*context));
  EXPECT_EQ(web_state, (*context)->GetWebState());
  EXPECT_EQ(*nav_id, (*context)->GetNavigationId());
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_EQ(has_user_gesture, (*context)->HasUserGesture());
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_TRUE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_TRUE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_EQ(renderer_initiated, (*context)->IsRendererInitiated());
  ASSERT_TRUE(web_state->IsLoading());
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetLastCommittedItem();
  EXPECT_TRUE(!item->GetTimestamp().is_null());
  EXPECT_EQ(url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for same page navigation
// passed to |DidFinishNavigation|. Stores |NavigationContext| in |context|
// pointer.
ACTION_P7(VerifySameDocumentStartedContext,
          web_state,
          url,
          has_user_gesture,
          context,
          nav_id,
          page_transition,
          renderer_initiated) {
  *context = arg1;
  ASSERT_TRUE(*context);
  EXPECT_EQ(web_state, arg0);
  EXPECT_EQ(web_state, (*context)->GetWebState());
  *nav_id = (*context)->GetNavigationId();
  EXPECT_NE(0, *nav_id);
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_EQ(has_user_gesture, (*context)->HasUserGesture());
  EXPECT_TRUE(PageTransitionTypeIncludingQualifiersIs(
      page_transition, (*context)->GetPageTransition()));
  EXPECT_TRUE((*context)->IsSameDocument());
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->GetResponseHeaders());
}

// Verifies correctness of |NavigationContext| (|arg1|) for same page navigation
// passed to |DidFinishNavigation|. Asserts that |NavigationContext| the same as
// |context|.
ACTION_P7(VerifySameDocumentFinishedContext,
          web_state,
          url,
          has_user_gesture,
          context,
          nav_id,
          page_transition,
          renderer_initiated) {
  ASSERT_EQ(*context, arg1);
  ASSERT_TRUE(*context);
  EXPECT_EQ(web_state, arg0);
  EXPECT_EQ(web_state, (*context)->GetWebState());
  EXPECT_EQ(*nav_id, (*context)->GetNavigationId());
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_EQ(has_user_gesture, (*context)->HasUserGesture());
  EXPECT_TRUE(PageTransitionTypeIncludingQualifiersIs(
      page_transition, (*context)->GetPageTransition()));
  EXPECT_TRUE((*context)->IsSameDocument());
  EXPECT_TRUE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->GetResponseHeaders());
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetLastCommittedItem();
  EXPECT_TRUE(!item->GetTimestamp().is_null());
  EXPECT_EQ(url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for reload navigation
// passed to |DidStartNavigation|. Stores |NavigationContext| in |context|
// pointer.
ACTION_P4(VerifyReloadStartedContext, web_state, url, context, nav_id) {
  *context = arg1;
  ASSERT_TRUE(*context);
  EXPECT_EQ(web_state, arg0);
  EXPECT_EQ(web_state, (*context)->GetWebState());
  *nav_id = (*context)->GetNavigationId();
  EXPECT_NE(0, *nav_id);
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  EXPECT_TRUE(
      PageTransitionCoreTypeIs(ui::PageTransition::PAGE_TRANSITION_RELOAD,
                               (*context)->GetPageTransition()));
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
  EXPECT_FALSE((*context)->GetResponseHeaders());
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetPendingItem();
  EXPECT_EQ(url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for reload navigation
// passed to |DidFinishNavigation|. Asserts that |NavigationContext| the same as
// |context|.
ACTION_P5(VerifyReloadFinishedContext,
          web_state,
          url,
          context,
          nav_id,
          is_web_page) {
  ASSERT_EQ(*context, arg1);
  ASSERT_TRUE(*context);
  EXPECT_EQ(web_state, arg0);
  EXPECT_EQ(web_state, (*context)->GetWebState());
  EXPECT_EQ(*nav_id, (*context)->GetNavigationId());
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  EXPECT_TRUE(
      PageTransitionCoreTypeIs(ui::PageTransition::PAGE_TRANSITION_RELOAD,
                               (*context)->GetPageTransition()));
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_TRUE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
  if (is_web_page) {
    ASSERT_TRUE((*context)->GetResponseHeaders());
    std::string mime_type;
    (*context)->GetResponseHeaders()->GetMimeType(&mime_type);
    EXPECT_EQ(kExpectedMimeType, mime_type);
  } else {
    EXPECT_FALSE((*context)->GetResponseHeaders());
  }
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetLastCommittedItem();
  EXPECT_TRUE(!item->GetTimestamp().is_null());
  EXPECT_EQ(url, item->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for download navigation
// passed to |DidFinishNavigation|. Asserts that |NavigationContext| the same as
// |context|.
ACTION_P4(VerifyDownloadFinishedContext, web_state, url, context, nav_id) {
  ASSERT_EQ(*context, arg1);
  EXPECT_EQ(web_state, arg0);
  ASSERT_TRUE((*context));
  EXPECT_EQ(web_state, (*context)->GetWebState());
  EXPECT_EQ(*nav_id, (*context)->GetNavigationId());
  EXPECT_EQ(url, (*context)->GetUrl());
  EXPECT_TRUE((*context)->HasUserGesture());
  EXPECT_TRUE(
      PageTransitionCoreTypeIs(ui::PageTransition::PAGE_TRANSITION_TYPED,
                               (*context)->GetPageTransition()));
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_TRUE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  EXPECT_FALSE((*context)->IsRendererInitiated());
}

// Verifies correctness of |NavigationContext| (|arg1|) for restoration
// navigation passed to |DidStartNavigation|. Stores |NavigationContext| in
// |context| pointer.
ACTION_P4(VerifyRestorationStartedContext, web_state, url, context, nav_id) {
  *context = arg1;
  ASSERT_TRUE(*context);
  EXPECT_EQ(web_state, arg0);
  EXPECT_EQ(web_state, (*context)->GetWebState());
  *nav_id = (*context)->GetNavigationId();
  EXPECT_NE(0, *nav_id);
  EXPECT_EQ(url, (*context)->GetUrl());
  // TODO(crbug.com/877671): restoration navigation should be
  // browser-initiated and should have user gesture.
  EXPECT_FALSE((*context)->HasUserGesture());
  ui::PageTransition actual_transition = (*context)->GetPageTransition();
  EXPECT_TRUE(PageTransitionCoreTypeIs(
      ui::PageTransition::PAGE_TRANSITION_RELOAD, actual_transition))
      << "Got unexpected transition: " << actual_transition;
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_FALSE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  // TODO(crbug.com/877671): restoration navigation should be
  // browser-initiated.
  EXPECT_TRUE((*context)->IsRendererInitiated());
  ASSERT_FALSE((*context)->GetResponseHeaders());
  ASSERT_TRUE(web_state->IsLoading());

  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  ASSERT_TRUE(navigation_manager->GetPendingItem());
  EXPECT_EQ(url, navigation_manager->GetPendingItem()->GetURL());
}

// Verifies correctness of |NavigationContext| (|arg1|) for restoration
// navigation passed to |DidFinishNavigation|. Asserts that |NavigationContext|
// the same as |context|.
ACTION_P5(VerifyRestorationFinishedContext,
          web_state,
          url,
          mime_type,
          context,
          nav_id) {
  ASSERT_EQ(*context, arg1);
  EXPECT_EQ(web_state, arg0);
  ASSERT_TRUE((*context));
  EXPECT_EQ(web_state, (*context)->GetWebState());
  EXPECT_EQ(*nav_id, (*context)->GetNavigationId());
  EXPECT_EQ(url, (*context)->GetUrl());
  // TODO(crbug.com/877671): restoration navigation should be
  // browser-initiated and should have user gesture.
  EXPECT_FALSE((*context)->HasUserGesture());
  ui::PageTransition actual_transition = (*context)->GetPageTransition();
  EXPECT_TRUE(PageTransitionCoreTypeIs(
      ui::PageTransition::PAGE_TRANSITION_RELOAD, actual_transition))
      << "Got unexpected transition: " << actual_transition;
  EXPECT_FALSE((*context)->IsSameDocument());
  EXPECT_TRUE((*context)->HasCommitted());
  EXPECT_FALSE((*context)->IsDownload());
  EXPECT_FALSE((*context)->IsPost());
  EXPECT_FALSE((*context)->GetError());
  // TODO(crbug.com/877671): restoration navigation should be
  // browser-initiated.
  EXPECT_TRUE((*context)->IsRendererInitiated());
  ASSERT_TRUE((*context)->GetResponseHeaders());
  std::string actual_mime_type;
  (*context)->GetResponseHeaders()->GetMimeType(&actual_mime_type);
  ASSERT_TRUE(web_state->IsLoading());
  EXPECT_EQ(mime_type, actual_mime_type);
  NavigationManager* navigation_manager = web_state->GetNavigationManager();
  NavigationItem* item = navigation_manager->GetLastCommittedItem();
  EXPECT_TRUE(!item->GetTimestamp().is_null());
  EXPECT_EQ(url, item->GetURL());
}

// A Google Mock matcher which matches |target_frame_is_main| member of
// WebStatePolicyDecider::RequestInfo. This is needed because
// WebStatePolicyDecider::RequestInfo doesn't support operator==.
MATCHER_P(RequestInfoMatch, expected_request_info, /*description=*/"") {
  bool transition_type_match = ui::PageTransitionTypeIncludingQualifiersIs(
      arg.transition_type, expected_request_info.transition_type);
  EXPECT_TRUE(transition_type_match)
      << "expected transition type: "
      << PageTransitionGetCoreTransitionString(
             expected_request_info.transition_type)
      << " actual transition type: "
      << PageTransitionGetCoreTransitionString(arg.transition_type);
  EXPECT_EQ(expected_request_info.target_frame_is_main,
            arg.target_frame_is_main);
  EXPECT_EQ(expected_request_info.target_frame_is_cross_origin,
            arg.target_frame_is_cross_origin);
  EXPECT_EQ(expected_request_info.has_user_gesture, arg.has_user_gesture);

  return transition_type_match &&
         arg.target_frame_is_main ==
             expected_request_info.target_frame_is_main &&
         arg.has_user_gesture == expected_request_info.has_user_gesture;
}

// A GMock matcher that matches |URL| member of |arg| with |expected_url|. |arg|
// is expected to be either an NSURLRequest or NSURLResponse.
MATCHER_P(URLMatch, expected_url, /*description=*/"") {
  return expected_url == net::GURLWithNSURL(arg.URL);
}

// Mocks WebStateObserver navigation callbacks.
class WebStateObserverMock : public WebStateObserver {
 public:
  WebStateObserverMock() = default;

  MOCK_METHOD2(DidStartNavigation, void(WebState*, NavigationContext*));
  MOCK_METHOD2(DidRedirectNavigation, void(WebState*, NavigationContext*));
  MOCK_METHOD2(DidFinishNavigation, void(WebState*, NavigationContext*));
  MOCK_METHOD1(DidStartLoading, void(WebState*));
  MOCK_METHOD1(DidStopLoading, void(WebState*));
  MOCK_METHOD2(PageLoaded, void(WebState*, PageLoadCompletionStatus));
  MOCK_METHOD1(DidChangeBackForwardState, void(WebState*));
  void WebStateDestroyed(WebState* web_state) override { NOTREACHED(); }

 private:
  DISALLOW_COPY_AND_ASSIGN(WebStateObserverMock);
};

// Mocks WebStateObserver navigation callbacks, including TitleWasSet.
class WebStateObserverWithTitleMock : public WebStateObserver {
 public:
  WebStateObserverWithTitleMock() = default;

  MOCK_METHOD2(DidStartNavigation, void(WebState*, NavigationContext*));
  MOCK_METHOD2(DidRedirectNavigation, void(WebState*, NavigationContext*));
  MOCK_METHOD2(DidFinishNavigation, void(WebState*, NavigationContext*));
  MOCK_METHOD1(DidStartLoading, void(WebState*));
  MOCK_METHOD1(DidStopLoading, void(WebState*));
  MOCK_METHOD2(PageLoaded, void(WebState*, PageLoadCompletionStatus));
  MOCK_METHOD1(DidChangeBackForwardState, void(WebState*));
  MOCK_METHOD1(TitleWasSet, void(WebState*));
  void WebStateDestroyed(WebState* web_state) override { NOTREACHED(); }

 private:
  DISALLOW_COPY_AND_ASSIGN(WebStateObserverWithTitleMock);
};

// Mocks WebStatePolicyDecider decision callbacks.
class PolicyDeciderMock : public WebStatePolicyDecider {
 public:
  PolicyDeciderMock(WebState* web_state) : WebStatePolicyDecider(web_state) {}

  void ShouldAllowRequest(
      NSURLRequest* request,
      const WebStatePolicyDecider::RequestInfo& request_info,
      WebStatePolicyDecider::PolicyDecisionCallback callback) override {
    MockShouldAllowRequest(request, request_info, callback);
  }
  MOCK_METHOD3(MockShouldAllowRequest,
               void(NSURLRequest*,
                    const WebStatePolicyDecider::RequestInfo& request_info,
                    WebStatePolicyDecider::PolicyDecisionCallback& callback));
  MOCK_METHOD3(ShouldAllowResponse,
               void(NSURLResponse*,
                    bool for_main_frame,
                    WebStatePolicyDecider::PolicyDecisionCallback callback));
};

}  // namespace

using net::test_server::EmbeddedTestServer;
using ::testing::Return;
using ::testing::StrictMock;
using ::testing::_;
using base::test::ios::kWaitForJSCompletionTimeout;
using base::test::ios::kWaitForPageLoadTimeout;
using base::test::ios::WaitUntilConditionOrTimeout;
using test::WaitForWebViewContainingText;

// Test fixture to test navigation and load callbacks from WebStateObserver and
// WebStatePolicyDecider.
template <class MockT>
class WebStateObserverTestBase : public WebIntTest {
 public:
  WebStateObserverTestBase() {}

  void SetUp() override {
    WebIntTest::SetUp();

    decider_ = std::make_unique<StrictMock<PolicyDeciderMock>>(web_state());
    scoped_observation_.Observe(web_state());

    test_server_ = std::make_unique<EmbeddedTestServer>();
    test_server_->RegisterRequestHandler(
        base::BindRepeating(&net::test_server::HandlePrefixedRequest, "/form",
                            base::BindRepeating(::testing::HandleForm)));
    test_server_->RegisterRequestHandler(base::BindRepeating(
        &net::test_server::HandlePrefixedRequest, "/download",
        base::BindRepeating(::testing::HandleDownload)));
    RegisterDefaultHandlers(test_server_.get());
    test_server_->ServeFilesFromSourceDirectory(
        base::FilePath("ios/testing/data/http_server_files/"));
    ASSERT_TRUE(test_server_->Start());
  }

  void TearDown() override {
    scoped_observation_.Reset();
    WebIntTest::TearDown();
  }

 protected:
  std::unique_ptr<StrictMock<PolicyDeciderMock>> decider_;
  StrictMock<MockT> observer_;
  std::unique_ptr<EmbeddedTestServer> test_server_;

 private:
  base::ScopedObservation<WebState, WebStateObserver> scoped_observation_{
      &observer_};

  DISALLOW_COPY_AND_ASSIGN(WebStateObserverTestBase);
};

class WebStateObserverTest
    : public WebStateObserverTestBase<WebStateObserverMock> {
 private:
  ::testing::InSequence callbacks_sequence_checker_;
};

class WebStateObserverWithTitleTest
    : public WebStateObserverTestBase<WebStateObserverWithTitleMock> {};

// Tests successful navigation to a new page.
TEST_F(WebStateObserverWithTitleTest, NewPageNavigation) {
  const GURL url = test_server_->GetURL("/echoall");

  // The call to update the final page title is asynchronous with respect to the
  // page loading flow and may occur at any time. This test enforces that:
  // 1) The non-title observer methods are called in order.
  // 2) The first TitleWasSet() call is immediately after DidFinishNavigation()
  // 3) The second TitleWasSet() call can happen any time after the first.
  ::testing::Sequence callbacks_sequence;
  ::testing::Sequence title_sequence;

  // Perform new page navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()))
      .InSequence(callbacks_sequence);
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .InSequence(callbacks_sequence)
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .InSequence(callbacks_sequence)
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .InSequence(callbacks_sequence)
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .InSequence(callbacks_sequence)
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), url, kExpectedMimeType, /*content_is_html=*/true,
          &context, &nav_id));
  EXPECT_CALL(observer_, TitleWasSet(web_state()))
      .InSequence(callbacks_sequence, title_sequence)
      .WillOnce(VerifyTitle(url.GetContent()));

  EXPECT_CALL(observer_, DidStopLoading(web_state()))
      .InSequence(callbacks_sequence);
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS))
      .InSequence(callbacks_sequence);

  EXPECT_CALL(observer_, TitleWasSet(web_state()))
      .InSequence(title_sequence)
      .WillOnce(VerifyTitle("EmbeddedTestServer - EchoAll"));

  // Load the page and wait for the final title update.
  ASSERT_TRUE(LoadUrl(url));
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForJSCompletionTimeout, ^{
    return web_state()->GetTitle() == u"EmbeddedTestServer - EchoAll";
  }));
}

// Tests successful navigation to a new page.
TEST_F(WebStateObserverTest, NewPageNavigation) {
  const GURL url = test_server_->GetURL("/echoall");

  // Perform new page navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), url, kExpectedMimeType, /*content_is_html=*/true,
          &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));
}

// Tests loading about://newtab and immediately loading another web page without
// waiting until about://newtab navigation finishes.
TEST_F(WebStateObserverTest, AboutNewTabNavigation) {
  GURL first_url("about://newtab/");
  const GURL second_url = test_server_->GetURL("/echoall");

  // Perform about://newtab navigation and immediately perform the second
  // navigation without waiting until the first navigation finishes.

  // Load |first_url|.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  // WKWebView.URL will change from |first_url| to |second_url|, then to nil
  // while WKWebView.loading changing to false and back to true immediately,
  // then to |first_url| again and the first navigation will finish.
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageConcurrentlyStartedContext(
          web_state(), first_url, second_url,
          ui::PageTransition::PAGE_TRANSITION_TYPED, &context, &nav_id));

  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), first_url, /*mime_type=*/std::string(),
          /*content_is_html=*/false, &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));

  // Load |second_url|.
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), second_url, ui::PageTransition::PAGE_TRANSITION_TYPED,
          &context, &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), second_url, kExpectedMimeType, /*content_is_html=*/true,
          &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  // Finish loading |second_url|.
  __block bool page_loaded = false;
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS))
      .WillOnce(::testing::Assign(&page_loaded, true));

  test::LoadUrl(web_state(), first_url);
  test::LoadUrl(web_state(), second_url);
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
    return page_loaded;
  }));
}

// Tests that if web usage is already enabled, enabling it again would not cause
// any page loads (related to restoring cached session). This is a regression
// test for crbug.com/781916.
TEST_F(WebStateObserverTest, EnableWebUsageTwice) {
  const GURL url = test_server_->GetURL("/echo");

  // Only expect one set of load events from the first LoadUrl(), not subsequent
  // SetWebUsageEnabled(true) calls. Web usage is already enabled, so the
  // subsequent calls should be noops.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), url, kExpectedMimeType, /*content_is_html=*/true,
          &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));

  ASSERT_TRUE(LoadUrl(url));
  web_state()->SetWebUsageEnabled(true);
  web_state()->SetWebUsageEnabled(true);
}

// Tests failed navigation to a new page.
TEST_F(WebStateObserverTest, FailedNavigation) {
  const GURL url = test_server_->GetURL("/close-socket");

  // Perform a navigation to url with unsupported scheme, which will fail.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));

  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  // Load placeholder by [WKWebView loadRequest].
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyErrorFinishedContext(web_state(), url, &context, &nav_id,
                                           /*committed=*/true,
                                           net::ERR_CONNECTION_CLOSED));

  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::FAILURE));

  if (!base::FeatureList::IsEnabled(features::kUseJSForErrorPage)) {
    // Load error page HTML by [WKWebView loadHTMLString:baseURL:].
    EXPECT_CALL(observer_, DidStartLoading(web_state()));
    EXPECT_CALL(observer_, DidStopLoading(web_state()));
  }

  test::LoadUrl(web_state(), url);

  // Ensure that title is not overridden by a placeholder navigation.
  web::NavigationManager* manager = web_state()->GetNavigationManager();
  web::NavigationItem* item = manager->GetPendingItem();
  item->SetTitle(kFailedTitle);
  ASSERT_TRUE(test::WaitForWebViewContainingText(
      web_state(), testing::GetErrorText(web_state(), url,
                                         testing::CreateConnectionLostError(),
                                         /*is_post=*/false, /*is_otr=*/false,
                                         /*cert_status=*/0)));
  EXPECT_EQ(item->GetTitle(), kFailedTitle);
}

// Tests that navigation to an invalid URL is disallowed.
TEST_F(WebStateObserverTest, InvalidURL) {
  // Navigations to invalid URLs are allowed on iOS 12 (see crbug.com/965067).
  if (!base::ios::IsRunningOnIOS13OrLater()) {
    return;
  }

  const GURL url = test_server_->GetURL("/echoall");

  // Perform new page navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), url, kExpectedMimeType, /*content_is_html=*/true,
          &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));

  // Navigate to an invalid URL using JavaScript.
  // There should be no calls to WebStatePolicyDecider, since the navigation
  // should get cancelled before that is reached.
  EXPECT_CALL(*decider_, MockShouldAllowRequest(_, _, _)).Times(0);
  ExecuteJavaScript(@"window.location.pathname = '/%00%50'");
}

// Tests navigation to a URL with /..; suffix. On iOS 12 and earlier this
// navigation fails becasue WebKit rewrites valid URL to invalid during the
// navigation. On iOS 13+ this navigation sucessfully completes.
TEST_F(WebStateObserverTest, UrlWithSpecialSuffixNavigation) {
  const std::string kBadSuffix = "/..;";
  GURL url = test_server_->GetURL(kBadSuffix);

  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  if (@available(iOS 13, *)) {
    // Starting from iOS 13 WebKit, does not rewrite URL.
    WebStatePolicyDecider::RequestInfo expected_request_info(
        ui::PageTransition::PAGE_TRANSITION_TYPED,
        /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
        /*has_user_gesture=*/false);
    EXPECT_CALL(*decider_, MockShouldAllowRequest(
                               _, RequestInfoMatch(expected_request_info), _))
        .WillOnce(
            RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
    EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
        .WillOnce(VerifyPageStartedContext(
            web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED,
            &context, &nav_id));
    EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
        .WillOnce(
            RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
    EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
        .WillOnce(VerifyNewPageFinishedContext(
            web_state(), url, /*mime_type*/ std::string(),
            /*content_is_html=*/false, &context, &nav_id));
    EXPECT_CALL(observer_, DidStopLoading(web_state()));

    EXPECT_CALL(observer_,
                PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));

    ASSERT_TRUE(LoadUrl(url));
    EXPECT_EQ(url, web_state()->GetVisibleURL());
  } else {
    // Perform a navigation to a url, which will be rewritten by WebKit to
    // invalid and will fail.
    std::string webkit_rewritten_url_spec = url.spec();
    // Prior to iOS 13, WebKit rewrites "http://127.0.0.1:80/..;" (valid) to
    // "http://127.0.0.1:80;/" (invalid).
    webkit_rewritten_url_spec.replace(url.spec().size() - kBadSuffix.size(),
                                      kBadSuffix.size(), ";/");

    WebStatePolicyDecider::RequestInfo expected_request_info(
        // Can't match NavigationContext and determine navigation type prior to
        // iOS 13, because context is matched by URL, which is rewritten by
        // WebKit.
        ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
        /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
        /*has_user_gesture=*/false);
    EXPECT_CALL(*decider_, MockShouldAllowRequest(
                               _, RequestInfoMatch(expected_request_info), _))
        .WillOnce(
            RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

    // WKWebView.URL changes from |url| nil and then to rewritten URL, while
    // WKWebView.loading changes from true to false and then back to true.
    EXPECT_CALL(observer_, DidStopLoading(web_state()));
    EXPECT_CALL(observer_, DidStartLoading(web_state()));

    EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
        .WillOnce(VerifyPageStartedContext(
            web_state(), GURL(webkit_rewritten_url_spec),
            ui::PageTransition::PAGE_TRANSITION_TYPED, &context, &nav_id));

    EXPECT_CALL(observer_, DidStopLoading(web_state()));

    EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
        .WillOnce(VerifyErrorFinishedContext(
            web_state(), GURL(webkit_rewritten_url_spec), &context, &nav_id,
            /*committed=*/false, net::ERR_FAILED));

    EXPECT_CALL(observer_,
                PageLoaded(web_state(), PageLoadCompletionStatus::FAILURE));

    ASSERT_TRUE(LoadUrl(url));
    EXPECT_EQ("", web_state()->GetVisibleURL());
  }
}

// Tests failed navigation because URL scheme is not supported by WKWebView.
TEST_F(WebStateObserverTest, WebViewUnsupportedSchemeNavigation) {
  GURL url(url::SchemeHostPort(kTestAppSpecificScheme, "foo", 0).Serialize());

  // Perform a navigation to url with unsupported scheme, which will fail.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));

  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  // Load placeholder by [WKWebView loadRequest].
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyErrorFinishedContext(web_state(), url, &context, &nav_id,
                                           /*committed=*/true,
                                           net::ERR_INVALID_URL));

  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::FAILURE));

  if (!base::FeatureList::IsEnabled(features::kUseJSForErrorPage)) {
    // Load error page HTML by [WKWebView loadHTMLString:baseURL:].
    EXPECT_CALL(observer_, DidStartLoading(web_state()));
    EXPECT_CALL(observer_, DidStopLoading(web_state()));
  }

  test::LoadUrl(web_state(), url);
  NSError* error = testing::CreateErrorWithUnderlyingErrorChain(
      {{NSURLErrorDomain, -1002}, {net::kNSErrorDomain, net::ERR_INVALID_URL}});
  ASSERT_TRUE(test::WaitForWebViewContainingText(
      web_state(), testing::GetErrorText(web_state(), url, error,
                                         /*is_post=*/false, /*is_otr=*/false,
                                         /*cert_status=*/0)));
}

// Tests failed navigation because URL with a space is not supported by
// WKWebView (crbug.com/934379).
TEST_F(WebStateObserverTest, WebViewUnsupportedUrlNavigation) {
  // TODO(crbug.com/1230089): This is now crashing the WebProcess on iOS15beta3.
  if (@available(iOS 15, *))
    return;

  GURL url("http:// .test");

  // Perform a navigation to url with unsupported url, which will fail.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));

  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  // Load placeholder by [WKWebView loadRequest].
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyErrorFinishedContext(web_state(), url, &context, &nav_id,
                                           /*committed=*/true,
                                           net::ERR_FAILED));

  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::FAILURE));

  if (!base::FeatureList::IsEnabled(features::kUseJSForErrorPage)) {
    // Load error page HTML by [WKWebView loadHTMLString:baseURL:].
    EXPECT_CALL(observer_, DidStartLoading(web_state()));
    EXPECT_CALL(observer_, DidStopLoading(web_state()));
  }

  test::LoadUrl(web_state(), url);
  NSError* error = testing::CreateErrorWithUnderlyingErrorChain(
      {{@"WebKitErrorDomain", 101}, {net::kNSErrorDomain, net::ERR_FAILED}});
  ASSERT_TRUE(test::WaitForWebViewContainingText(
      web_state(), testing::GetErrorText(web_state(), url, error,
                                         /*is_post=*/false, /*is_otr=*/false,
                                         /*cert_status=*/0)));
}

// Tests failed navigation because URL scheme is not supported by WebState.
TEST_F(WebStateObserverTest, WebStateUnsupportedSchemeNavigation) {
  GURL url("ftp://foo.test/");

  // Perform a navigation to url with unsupported scheme.
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  // ShouldAllowRequest is called to give embedder a chance to handle
  // this unsupported URL scheme.
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  test::LoadUrl(web_state(), url);
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));

  // Typed URL should be discarded after the navigation is rejected.
  EXPECT_FALSE(web_state()->GetNavigationManager()->GetVisibleItem());
}

// Tests web page reload navigation.
TEST_F(WebStateObserverTest, WebPageReloadNavigation) {
  const GURL url = test_server_->GetURL("/echoall");

  // Perform new page navigation.
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));

  // Reload web page.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo reload_request_info(
      ui::PageTransition::PAGE_TRANSITION_RELOAD,
      /*target_main_frame=*/true,
      /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(reload_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(
          VerifyReloadStartedContext(web_state(), url, &context, &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyReloadFinishedContext(web_state(), url, &context, &nav_id,
                                            true /* is_web_page */));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(ExecuteBlockAndWaitForLoad(url, ^{
    navigation_manager()->Reload(ReloadType::NORMAL,
                                 /*check_for_repost=*/false);
  }));
}

// Tests web page reload with user agent override.
// TODO(crbug.com/851119): temporarily disable this failing test.
TEST_F(WebStateObserverTest, DISABLED_ReloadWithUserAgentType) {
  const GURL url = test_server_->GetURL("/echo");

  // Perform new page navigation.
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));

  // Reload web page with desktop user agent.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_reload_request_info(
      ui::PageTransition::PAGE_TRANSITION_RELOAD,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(
                  _, RequestInfoMatch(expected_reload_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_RELOAD,
          &context, &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  // TODO(crbug.com/798836): verify the correct User-Agent header is sent.
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  web_state()->SetDelegate(nullptr);
  ASSERT_TRUE(ExecuteBlockAndWaitForLoad(url, ^{
    navigation_manager()->ReloadWithUserAgentType(UserAgentType::DESKTOP);
  }));
}

// Tests user-initiated hash change.
TEST_F(WebStateObserverTest, UserInitiatedHashChangeNavigation) {
  const GURL url = test_server_->GetURL("/echoall");

  // Perform new page navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), url, kExpectedMimeType, /*content_is_html=*/true,
          &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));

  // Perform same-document navigation.
  const GURL hash_url = test_server_->GetURL("/echoall#1");
  WebStatePolicyDecider::RequestInfo hash_url_expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);

  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(
                  _, RequestInfoMatch(hash_url_expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifySameDocumentStartedContext(
          web_state(), hash_url, /*has_user_gesture=*/true, &context, &nav_id,
          ui::PageTransition::PAGE_TRANSITION_TYPED,
          /*renderer_initiated=*/false));

  // No ShouldAllowResponse callback for same-document navigations.
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifySameDocumentFinishedContext(
          web_state(), hash_url, /*has_user_gesture=*/true, &context, &nav_id,
          ui::PageTransition::PAGE_TRANSITION_TYPED,
          /*renderer_initiated=*/false));

  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(hash_url));

  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  // Perform same-document navigation by going back.
  // No ShouldAllowRequest callback for same-document back-forward navigations.

  // Called once each for CanGoBack and CanGoForward.
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state())).Times(2);
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  ui::PageTransition expected_transition = static_cast<ui::PageTransition>(
      ui::PageTransition::PAGE_TRANSITION_FORWARD_BACK |
      ui::PageTransition::PAGE_TRANSITION_TYPED);
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifySameDocumentStartedContext(
          web_state(), url, /*has_user_gesture=*/true, &context, &nav_id,
          expected_transition, /*renderer_initiated=*/false));

  // No ShouldAllowResponse callbacks for same-document back-forward
  // navigations.
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifySameDocumentFinishedContext(
          web_state(), url, /*has_user_gesture=*/true, &context, &nav_id,
          expected_transition, /*renderer_initiated=*/false));

  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(ExecuteBlockAndWaitForLoad(url, ^{
    navigation_manager()->GoBack();
  }));
}

// Tests renderer-initiated hash change.
TEST_F(WebStateObserverTest, RendererInitiatedHashChangeNavigation) {
  const GURL url = test_server_->GetURL("/echoall");

  // Perform new page navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), url, kExpectedMimeType, /*content_is_html=*/true,
          &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));

  // Perform same-page navigation using JavaScript.
  const GURL hash_url = test_server_->GetURL("/echoall#1");
  WebStatePolicyDecider::RequestInfo expected_hash_request_info(
      ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(
                  _, RequestInfoMatch(expected_hash_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));

  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifySameDocumentStartedContext(
          web_state(), hash_url, /*has_user_gesture=*/false, &context, &nav_id,
          ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
          /*renderer_initiated=*/true));
  // No ShouldAllowResponse callback for same-document navigations.
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifySameDocumentFinishedContext(
          web_state(), hash_url, /*has_user_gesture=*/false, &context, &nav_id,
          ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
          /*renderer_initiated=*/true));

  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ExecuteJavaScript(@"window.location.hash = '#1'");
}

// Tests state change.
TEST_F(WebStateObserverTest, StateNavigation) {
  const GURL url = test_server_->GetURL("/echoall");

  // Perform new page navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), url, kExpectedMimeType, /*content_is_html=*/true,
          &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));

  // Perform push state using JavaScript.
  const GURL push_url = test_server_->GetURL("/test.html");
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifySameDocumentStartedContext(
          web_state(), push_url, /*has_user_gesture=*/false, &context, &nav_id,
          ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
          /*renderer_initiated=*/true));
  // No ShouldAllowRequest/ShouldAllowResponse callbacks for same-document push
  // state navigations.
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifySameDocumentFinishedContext(
          web_state(), push_url, /*has_user_gesture=*/false, &context, &nav_id,
          ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
          /*renderer_initiated=*/true));
  ExecuteJavaScript(@"window.history.pushState('', 'Test', 'test.html')");

  // Perform replace state using JavaScript.
  const GURL replace_url = test_server_->GetURL("/1.html");
  // No ShouldAllowRequest callbacks for same-document push state navigations.
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifySameDocumentStartedContext(
          web_state(), replace_url, /*has_user_gesture=*/false, &context,
          &nav_id, ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
          /*renderer_initiated=*/true));
  // No ShouldAllowResponse callbacks for same-document push state navigations.
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifySameDocumentFinishedContext(
          web_state(), replace_url, /*has_user_gesture=*/false, &context,
          &nav_id, ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
          /*renderer_initiated=*/true));
  ExecuteJavaScript(@"window.history.replaceState('', 'Test', '1.html')");
}

// Tests successful navigation to a new page with post HTTP method.
TEST_F(WebStateObserverTest, UserInitiatedPostNavigation) {
  const GURL url = test_server_->GetURL("/echo");

  // Perform new page navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_GENERATED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPostStartedContext(
          web_state(), url, /*has_user_gesture=*/true, &context, &nav_id,
          /*renderer_initiated=*/false));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyPostFinishedContext(
          web_state(), url, /*has_user_gesture=*/true, &context, &nav_id,
          /*renderer_initiated=*/false));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));

  // Load request using POST HTTP method.
  NavigationManager::WebLoadParams params(url);
  params.post_data = [@"foo" dataUsingEncoding:NSUTF8StringEncoding];
  params.extra_headers = @{@"Content-Type" : @"text/html"};
  params.transition_type = ui::PageTransition::PAGE_TRANSITION_GENERATED;
  ASSERT_TRUE(LoadWithParams(params));
  ASSERT_TRUE(WaitForWebViewContainingText(web_state(), "foo"));
}

// Tests successful navigation to a new page with post HTTP method.
TEST_F(WebStateObserverTest, RendererInitiatedPostNavigation) {
  const GURL url = test_server_->GetURL("/form?echoall");
  const GURL action = test_server_->GetURL("/echoall");

  // Perform new page navigation.
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));
  ASSERT_TRUE(
      WaitForWebViewContainingText(web_state(), ::testing::kTestFormPage));

  // Submit the form using JavaScript.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  WebStatePolicyDecider::RequestInfo form_request_info(
      ui::PageTransition::PAGE_TRANSITION_FORM_SUBMIT,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(_, RequestInfoMatch(form_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPostStartedContext(
          web_state(), action, /*has_user_gesture=*/false, &context, &nav_id,
          /*renderer_initiated=*/true));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyPostFinishedContext(
          web_state(), action, /*has_user_gesture=*/false, &context, &nav_id,
          /*renderer_initiated=*/true));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ExecuteJavaScript(@"document.getElementById('form').submit();");
  ASSERT_TRUE(WaitForWebViewContainingText(web_state(),
                                           ::testing::kTestFormFieldValue));
}

// Tests successful reload of a page returned for post request.
TEST_F(WebStateObserverTest, ReloadPostNavigation) {
  const GURL url = test_server_->GetURL("/form?echoall");
  const GURL action = test_server_->GetURL("/echoall");

  // Perform new page navigation.
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));
  ASSERT_TRUE(
      WaitForWebViewContainingText(web_state(), ::testing::kTestFormPage));

  // Submit the form using JavaScript.
  WebStatePolicyDecider::RequestInfo form_request_info(
      ui::PageTransition::PAGE_TRANSITION_FORM_SUBMIT,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(_, RequestInfoMatch(form_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ExecuteJavaScript(@"window.document.getElementById('form').submit();");
  ASSERT_TRUE(WaitForWebViewContainingText(web_state(),
                                           ::testing::kTestFormFieldValue));

  // Reload the page.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  WebStatePolicyDecider::RequestInfo form_reload_request_info(
      ui::PageTransition::PAGE_TRANSITION_RELOAD,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(form_reload_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPostStartedContext(
          web_state(), action, /*has_user_gesture=*/true, &context, &nav_id,
          /*reload_is_renderer_initiated=*/false));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyPostFinishedContext(
          web_state(), action, /*has_user_gesture=*/true, &context, &nav_id,
          /*reload_is_renderer_initiated=*/false));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  // TODO(crbug.com/700958): ios/web ignores |check_for_repost| flag and current
  // delegate does not run callback for ShowRepostFormWarningDialog. Clearing
  // the delegate will allow form resubmission. Remove this workaround (clearing
  // the delegate, once |check_for_repost| is supported).
  web_state()->SetDelegate(nullptr);
  ASSERT_TRUE(ExecuteBlockAndWaitForLoad(action, ^{
    navigation_manager()->Reload(ReloadType::NORMAL,
                                 false /*check_for_repost*/);
  }));
}

// Tests going forward to a page rendered from post response.
TEST_F(WebStateObserverTest, ForwardPostNavigation) {
  const GURL url = test_server_->GetURL("/form?echo");
  const GURL action = test_server_->GetURL("/echo");

  // Perform new page navigation.
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));
  ASSERT_TRUE(
      WaitForWebViewContainingText(web_state(), ::testing::kTestFormPage));

  // Submit the form using JavaScript.
  WebStatePolicyDecider::RequestInfo form_request_info(
      ui::PageTransition::PAGE_TRANSITION_FORM_SUBMIT,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(_, RequestInfoMatch(form_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ExecuteJavaScript(@"window.document.getElementById('form').submit();");
  ASSERT_TRUE(WaitForWebViewContainingText(web_state(),
                                           ::testing::kTestFormFieldValue));

  // Go Back.
  WebStatePolicyDecider::RequestInfo back_request_info(
      static_cast<ui::PageTransition>(
          ui::PageTransition::PAGE_TRANSITION_FORWARD_BACK |
          ui::PageTransition::PAGE_TRANSITION_TYPED),
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state())).Times(2);
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(_, RequestInfoMatch(back_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(ExecuteBlockAndWaitForLoad(url, ^{
    navigation_manager()->GoBack();
  }));

  // Go forward.
  WebStatePolicyDecider::RequestInfo forward_request_info(
      static_cast<ui::PageTransition>(
          ui::PageTransition::PAGE_TRANSITION_FORM_SUBMIT |
          ui::PageTransition::PAGE_TRANSITION_FORWARD_BACK),
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state())).Times(2);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(forward_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPostStartedContext(web_state(), action,
                                         /*has_user_gesture=*/true, &context,
                                         &nav_id,
                                         /*renderer_initiated=*/false));

  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyPostFinishedContext(web_state(), action,
                                          /*has_user_gesture=*/true, &context,
                                          &nav_id,
                                          /*renderer_initiated=*/false));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  // TODO(crbug.com/700958): ios/web ignores |check_for_repost| flag and current
  // delegate does not run callback for ShowRepostFormWarningDialog. Clearing
  // the delegate will allow form resubmission. Remove this workaround (clearing
  // the delegate, once |check_for_repost| is supported).
  web_state()->SetDelegate(nullptr);
  ASSERT_TRUE(ExecuteBlockAndWaitForLoad(action, ^{
    navigation_manager()->GoForward();
  }));
}

// Tests server redirect navigation.
TEST_F(WebStateObserverTest, RedirectNavigation) {
  const GURL url = test_server_->GetURL("/server-redirect-301?"
                                        "server-redirect-302?"
                                        "server-redirect-303?"
                                        "server-redirect-307?"
                                        "server-redirect-308?"
                                        "echoall");
  const GURL redirect_url = test_server_->GetURL("/echoall");

  // Load url which replies with redirect.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));

  // 5 calls on ShouldAllowRequest and DidRedirectNavigation for redirections.
  WebStatePolicyDecider::RequestInfo expected_redirect_request_info(
      ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(
                  _, RequestInfoMatch(expected_redirect_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidRedirectNavigation(web_state(), _));
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(
                  _, RequestInfoMatch(expected_redirect_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidRedirectNavigation(web_state(), _));
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(
                  _, RequestInfoMatch(expected_redirect_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidRedirectNavigation(web_state(), _));
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(
                  _, RequestInfoMatch(expected_redirect_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidRedirectNavigation(web_state(), _));
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(
                  _, RequestInfoMatch(expected_redirect_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidRedirectNavigation(web_state(), _));

  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), redirect_url, kExpectedMimeType,
          /*content_is_html=*/true, &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));
}

// Tests download navigation.
TEST_F(WebStateObserverTest, DownloadNavigation) {
  GURL url = test_server_->GetURL("/download");

  // Perform download navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(
          VerifyDownloadFinishedContext(web_state(), url, &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  test::LoadUrl(web_state(), url);
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));

  EXPECT_FALSE(web_state()->GetNavigationManager()->GetPendingItem());
}

// Tests failed load after the navigation is sucessfully finished.
// TODO(crbug.com/954232): this test is flaky on device, and as of iOS14
// simulator as well.
TEST_F(WebStateObserverTest, FLAKY_FailedLoad) {
  GURL url = test_server_->GetURL("/exabyte_response");

  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(web_state(), url, /*mime_type=*/"",
                                             /*content_is_html=*/false,
                                             &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::FAILURE));

  if (!base::FeatureList::IsEnabled(features::kUseJSForErrorPage)) {
    // Load error page HTML by [WKWebView loadHTMLString:baseURL:].
    EXPECT_CALL(observer_, DidStartLoading(web_state()));
    EXPECT_CALL(observer_, DidStopLoading(web_state()));
  }

  test::LoadUrl(web_state(), url);

  // Server will never stop responding. Wait until the navigation is committed.
  EXPECT_FALSE(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
    return context && context->HasCommitted();
  }));

  // At this point the navigation should be finished. Shutdown the server and
  // wait until web state stop loading.
  ASSERT_TRUE(test_server_->ShutdownAndWaitUntilComplete());
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));
}

// Tests navigation to a page with self signed SSL cert.
TEST_F(WebStateObserverTest, FailedSslConnection) {
  EmbeddedTestServer https_server(EmbeddedTestServer::TYPE_HTTPS);
  ASSERT_TRUE(https_server.Start());

  const GURL url = https_server.GetURL("/");
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(_, RequestInfoMatch(request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  // First, a placeholder navigation starts and finishes.
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::FAILURE));

  if (!base::FeatureList::IsEnabled(features::kUseJSForErrorPage)) {
    // Finally, the error page itself is loaded.
    EXPECT_CALL(observer_, DidStartLoading(web_state()));
    EXPECT_CALL(observer_, DidStopLoading(web_state()));
  }

  test::LoadUrl(web_state(), url);
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
    base::RunLoop().RunUntilIdle();
    return !web_state()->IsLoading();
  }));
}

// Tests cancelling the navigation from ShouldAllowRequest. The load should
// stop, but no other callbacks are called.
TEST_F(WebStateObserverTest, DisallowRequest) {
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Cancel()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  test::LoadUrl(web_state(), test_server_->GetURL("/echo"));
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));

  // Typed URL should be discarded after the navigation is rejected.
  EXPECT_FALSE(web_state()->GetNavigationManager()->GetVisibleItem());
}

// Tests rejecting the navigation from ShouldAllowRequest with an error. The
// load should stop, and an error page should be loaded.
TEST_F(WebStateObserverTest, DisallowRequestAndShowError) {
  base::test::ScopedFeatureList feature_list;
  feature_list.InitAndEnableFeature(web::features::kUseJSForErrorPage);

  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  NSError* error = [NSError errorWithDomain:net::kNSErrorDomain
                                       code:net::ERR_BLOCKED_BY_ADMINISTRATOR
                                   userInfo:nil];
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(RunOnceCallback<2>(
          WebStatePolicyDecider::PolicyDecision::CancelAndDisplayError(error)));

  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::FAILURE));

  GURL url = test_server_->GetURL("/echo");
  test::LoadUrl(web_state(), url);

  EXPECT_TRUE(test::WaitForWebViewContainingText(
      web_state(), testing::GetErrorText(web_state(), url, error,
                                         /*is_post=*/false, /*is_otr=*/false,
                                         /*cert_status=*/0)));
  // The URL of the error page should remain the URL of the blocked page.
  EXPECT_EQ(url.spec(), web_state()->GetVisibleURL());
}

// Tests allowing the navigation from ShouldAllowResponse using an async
// decider.
TEST_F(WebStateObserverTest, AsyncAllowResponse) {
  const GURL url = test_server_->GetURL("/echoall");
  AsyncWebStatePolicyDecider async_decider(web_state());

  // Perform new page navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  test::LoadUrl(web_state(), url);
  AsyncWebStatePolicyDecider* async_decider_ptr = &async_decider;
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
    return async_decider_ptr->ReadyToInvokeCallback();
  }));

  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), url, kExpectedMimeType, /*content_is_html=*/true,
          &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  async_decider.InvokeCallback(WebStatePolicyDecider::PolicyDecision::Allow());

  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));
  EXPECT_EQ(url.spec(), web_state()->GetVisibleURL());
}

// Tests rejecting the navigation from ShouldAllowResponse. PageLoaded callback
// is not called.
TEST_F(WebStateObserverTest, DisallowResponse) {
  const GURL url = test_server_->GetURL("/echo");

  // Perform new page navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Cancel()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyResponseRejectedFinishedContext(web_state(), url,
                                                      &context, &nav_id));
  test::LoadUrl(web_state(), test_server_->GetURL("/echo"));
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));
  EXPECT_EQ("", web_state()->GetVisibleURL());
}

// Tests rejecting the navigation from ShouldAllowResponse using an async
// decider.
TEST_F(WebStateObserverTest, AsyncDisallowResponse) {
  const GURL url = test_server_->GetURL("/echo");
  AsyncWebStatePolicyDecider async_decider(web_state());

  // Perform new page navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  test::LoadUrl(web_state(), test_server_->GetURL("/echo"));
  AsyncWebStatePolicyDecider* async_decider_ptr = &async_decider;
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
    return async_decider_ptr->ReadyToInvokeCallback();
  }));

  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyResponseRejectedFinishedContext(web_state(), url,
                                                      &context, &nav_id));
  async_decider.InvokeCallback(WebStatePolicyDecider::PolicyDecision::Cancel());

  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));
  EXPECT_EQ("", web_state()->GetVisibleURL());
}

// Tests stopping a navigation. Did FinishLoading and PageLoaded are never
// called.
TEST_F(WebStateObserverTest, ImmediatelyStopNavigation) {
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  test::LoadUrl(web_state(), test_server_->GetURL("/hung"));
  web_state()->Stop();
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));
  EXPECT_EQ("", web_state()->GetVisibleURL());
}

// Tests stopping a navigation after allowing the navigation from
// WebStatePolicyDecider. DidStartNavigation and DidFinishNavigation callbacks
// are still called on simulator. On iOS 12.2 device the navigation never
// starts, which is ok, but the behavior can not be tested so the test is
// simulator-only.
#if TARGET_IPHONE_SIMULATOR
TEST_F(WebStateObserverTest, StopNavigationAfterPolicyDeciderCallback) {
  if (@available(iOS 13, *)) {
    // The navigation may or may not start, which is ok, but there is no need to
    // test this scenario.
    return;
  }

  GURL url(test_server_->GetURL("/hung"));
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(WithArgs<2>(ReturnAllowRequestAndStopNavigation(web_state())));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyAbortedNavigationStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyResponseRejectedFinishedContext(web_state(), url,
                                                      &context, &nav_id));

  // Load the page and wait for DidFinishNavigation callback.
  FakeWebStateObserver page_loaded_observer(web_state());
  test::LoadUrl(web_state(), url);
  FakeWebStateObserver* page_loaded_observer_ptr = &page_loaded_observer;
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^bool {
    return page_loaded_observer_ptr->did_finish_navigation_info();
  }));
}
#endif  // TARGET_IPHONE_SIMULATOR

// Tests stopping a finished navigation. PageLoaded is never called.
TEST_F(WebStateObserverTest, StopFinishedNavigation) {
  GURL url = test_server_->GetURL("/exabyte_response");

  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(web_state(), url, /*mime_type=*/"",
                                             /*content_is_html=*/false,
                                             &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  test::LoadUrl(web_state(), url);

  // Server will never stop responding. Wait until the navigation is committed.
  EXPECT_FALSE(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
    return context && context->HasCommitted();
  }));

  // Stop the loading.
  web_state()->Stop();
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));

  // This test will create an unresponsive WebProcess. WebIntTest::TearDown will
  // call ClearBrowingData, which can take a very long time with an unresponsive
  // WebProcess. Work around this problem by force closing WKWebView via a
  // private API.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
  web::WebStateImpl* web_state_impl =
      static_cast<web::WebStateImpl*>(web_state());
  WKWebView* web_view = base::mac::ObjCCast<WKWebView>(
      web_state_impl->GetWebViewNavigationProxy());
  [web_view performSelector:@selector(_close)];
#pragma clang diagnostic pop
}

// Tests that iframe navigation triggers DidChangeBackForwardState.
TEST_F(WebStateObserverTest, IframeNavigation) {
  // This test fails in iOS 13.4 but is fixed in iOS 14. See crbug.com//1076233.
  if (base::ios::IsRunningOnOrLater(13, 4, 0) &&
      !base::ios::IsRunningOnIOS14OrLater()) {
    return;
  }

  GURL url = test_server_->GetURL("/iframe_host.html");

  // Callbacks due to loading of the main frame.
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));

  // Callbacks due to initial loading of iframe.
  WebStatePolicyDecider::RequestInfo iframe_request_info(
      ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
      /*target_main_frame=*/false, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(iframe_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/false, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));

  test::LoadUrl(web_state(), url);
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));

  // Trigger different-document load in iframe.
  WebStatePolicyDecider::RequestInfo link_clicked_request_info(
      ui::PageTransition::PAGE_TRANSITION_LINK,
      /*target_main_frame=*/false, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/true);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(link_clicked_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/false, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));
  test::TapWebViewElementWithIdInIframe(web_state(), "normal-link");
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^bool {
    std::unique_ptr<base::Value> URL =
        ExecuteJavaScript(@"window.frames[0].location.pathname;");
    return URL->is_string() && URL->GetString() == "/pony.html";
  }));
  ASSERT_TRUE(web_state()->GetNavigationManager()->CanGoBack());
  ASSERT_FALSE(web_state()->GetNavigationManager()->CanGoForward());
  std::unique_ptr<base::Value> history_length =
      ExecuteJavaScript(@"history.length;");
  ASSERT_TRUE(history_length->is_double());
  ASSERT_EQ(2, history_length->GetDouble());

  // Go back to top.
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo forward_back_request_info(
      ui::PageTransition::PAGE_TRANSITION_FORWARD_BACK,
      /*target_main_frame=*/false, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/true);
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()))
      .Times(2);  // called once each for canGoBack and canGoForward
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(forward_back_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/false, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  web_state()->GetNavigationManager()->GoBack();
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^bool {
    std::unique_ptr<base::Value> URL =
        ExecuteJavaScript(@"window.frames[0].location.pathname;");
    return URL->is_string() && URL->GetString() == "/links.html";
  }));
  ASSERT_TRUE(web_state()->GetNavigationManager()->CanGoForward());
  ASSERT_FALSE(web_state()->GetNavigationManager()->CanGoBack());

  // Trigger same-document load in iframe.
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(link_clicked_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  // ShouldAllowResponse() is not called for same-document navigation.
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()))
      .Times(2);  // called once each for canGoBack and canGoForward
  test::TapWebViewElementWithIdInIframe(web_state(), "same-page-link");
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
    return web_state()->GetNavigationManager()->CanGoBack();
  }));
  EXPECT_FALSE(web_state()->GetNavigationManager()->CanGoForward());
}

// Tests that cross-origin iframe navigation is correctly identified in
// WebStatePolicyDecider::RequestInfo.
TEST_F(WebStateObserverTest, CrossOriginIframeNavigation) {
  EmbeddedTestServer cross_origin_server;
  RegisterDefaultHandlers(&cross_origin_server);
  ASSERT_TRUE(cross_origin_server.Start());

  GURL url = test_server_->GetURL("/iframe_host.html");

  // Callbacks due to loading of the main frame.
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));

  // Callbacks due to initial loading of iframe.
  WebStatePolicyDecider::RequestInfo iframe_request_info(
      ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
      /*target_main_frame=*/false, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(iframe_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/false, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));

  test::LoadUrl(web_state(), url);
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));

  // Load a cross-origin URL in the iframe. In this case, the target frame is
  // same-origin since the currently-loaded URL in the iframe is same-origin
  // with respect to the main frame.
  GURL cross_origin_url = cross_origin_server.GetURL("/echo");
  WebStatePolicyDecider::RequestInfo iframe_request_info2(
      ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
      /*target_main_frame=*/false, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(iframe_request_info2), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/false, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));
  ExecuteJavaScript(
      [NSString stringWithFormat:@"window.frames[0].location.href='%s';",
                                 cross_origin_url.spec().c_str()]);
  ASSERT_TRUE(test::WaitForWebViewContainingTextInFrame(web_state(), "Echo"));
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));

  // Now load another URL in the iframe. The iframe (that is, the target frame)
  // is now cross-origin with respect to the main frame.
  GURL url2 = test_server_->GetURL("/pony.html");
  WebStatePolicyDecider::RequestInfo iframe_request_info3(
      ui::PageTransition::PAGE_TRANSITION_CLIENT_REDIRECT,
      /*target_main_frame=*/false, /*target_frame_is_cross_origin=*/true,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(iframe_request_info3), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/false, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  ExecuteJavaScript(
      [NSString stringWithFormat:@"window.frames[0].location.href='%s';",
                                 url2.spec().c_str()]);
  ASSERT_TRUE(test::WaitForWebViewContainingTextInFrame(web_state(), "pony"));
  ASSERT_TRUE(test::WaitForPageToFinishLoading(web_state()));
}

// Tests that new page load calls NavigationItemsPruned callback if there were
// forward navigation items.
TEST_F(WebStateObserverTest, NewPageLoadDestroysForwardItems) {
  // Perform first navigation.
  const GURL first_url = test_server_->GetURL("/echoall");
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(*decider_, MockShouldAllowRequest(_, _, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(first_url));

  // Perform second navigation.
  const GURL hash_url = test_server_->GetURL("/echoall#1");
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(*decider_, MockShouldAllowRequest(_, _, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  // No ShouldAllowResponse callback for same-document navigations.
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(hash_url));

  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  // Go back to create forward navigation items.

  // Called once each for CanGoBack and CanGoForward;
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state())).Times(2);

  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  // No ShouldAllowResponse callbacks for same-document back-forward
  // navigations.

  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));

  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(ExecuteBlockAndWaitForLoad(first_url, ^{
    navigation_manager()->GoBack();
  }));

  // New page load destroys forward navigation entries.
  const GURL url = test_server_->GetURL("/echo");
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(*decider_, MockShouldAllowRequest(_, _, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  // Called once each for CanGoBack and CanGoForward;
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state())).Times(2);
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(url));
}

// Tests callbacks for restoring session and subsequently going back to
// about:blank.
TEST_F(WebStateObserverTest, RestoreSessionOnline) {
  // Create a session of 3 items. Current item is at index 1.
  const GURL url0("about:blank");
  auto item0 = std::make_unique<NavigationItemImpl>();
  item0->SetURL(url0);

  const GURL url1 = test_server_->GetURL("/echo?1");
  auto item1 = std::make_unique<NavigationItemImpl>();
  item1->SetURL(url1);

  const GURL url2 = test_server_->GetURL("/echo?2");
  auto item2 = std::make_unique<NavigationItemImpl>();
  item2->SetURL(url2);

  __block std::vector<std::unique_ptr<NavigationItem>> restored_items;
  restored_items.push_back(std::move(item0));
  restored_items.push_back(std::move(item1));
  restored_items.push_back(std::move(item2));

  // Initiate session restoration.

  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  EXPECT_CALL(*decider_, MockShouldAllowRequest(_, _, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  // Back/forward state changes due to History API calls during session
  // restoration. Called once each for CanGoBack and CanGoForward.
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));

  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state()));

  // Client-side redirect to restore_session.html?targetUrl=url1.
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(URLMatch(CreateRedirectUrl(url1)), _, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  EXPECT_CALL(*decider_, ShouldAllowResponse(URLMatch(CreateRedirectUrl(url1)),
                                             /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  // Client-side redirect to |url1|.
  EXPECT_CALL(*decider_, MockShouldAllowRequest(URLMatch(url1), _, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  EXPECT_CALL(*decider_,
              ShouldAllowResponse(URLMatch(url1), /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));

  ASSERT_TRUE(ExecuteBlockAndWaitForLoad(url1, ^{
    navigation_manager()->Restore(/*last_committed_item_index=*/1,
                                  std::move(restored_items));
  }));
  ASSERT_EQ(url1, navigation_manager()->GetLastCommittedItem()->GetURL());
  EXPECT_EQ(1, navigation_manager()->GetLastCommittedItemIndex());
  ASSERT_EQ(3, navigation_manager()->GetItemCount());
  ASSERT_TRUE(navigation_manager()->CanGoBack());
  ASSERT_TRUE(navigation_manager()->CanGoForward());

  // Go back to |item0|.

  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  // Only CanGoBackward changes state on this navigation.
  EXPECT_CALL(observer_, DidChangeBackForwardState(web_state())).Times(1);

  // Load restore_session.html?targetUrl=url0.
  EXPECT_CALL(*decider_,
              MockShouldAllowRequest(URLMatch(CreateRedirectUrl(url0)), _, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(*decider_, ShouldAllowResponse(URLMatch(CreateRedirectUrl(url0)),
                                             /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  EXPECT_CALL(observer_, DidStopLoading(web_state()));

  // Client-side redirect to |url0|.
  EXPECT_CALL(*decider_, MockShouldAllowRequest(URLMatch(url0), _, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));

  EXPECT_CALL(observer_, DidStartLoading(web_state()));

  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _));
  // No ShouldAllowResponse call because about:blank has no response.
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));

  ASSERT_TRUE(ExecuteBlockAndWaitForLoad(url0, ^{
    navigation_manager()->GoBack();
  }));
  ASSERT_EQ(url0, navigation_manager()->GetLastCommittedItem()->GetURL());
  EXPECT_EQ(0, navigation_manager()->GetLastCommittedItemIndex());
  ASSERT_TRUE(navigation_manager()->CanGoForward());
  ASSERT_FALSE(navigation_manager()->CanGoBack());
}

// Tests that if a saved session is provided when creating a new WebState, it is
// restored after the first NavigationManager::LoadIfNecessary() call.
TEST_F(WebStateObserverTest, RestoredFromHistory) {
  auto web_state = WebState::CreateWithStorageSession(
      WebState::CreateParams(GetBrowserState()),
      GetTestSessionStorage(test_server_->GetURL(kTestPageURL)));

  ASSERT_FALSE(test::IsWebViewContainingText(web_state.get(),
                                             kTestSessionStoragePageText));
  web_state->GetNavigationManager()->LoadIfNecessary();
  EXPECT_TRUE(test::WaitForWebViewContainingText(web_state.get(),
                                                 kTestSessionStoragePageText));
}

// Tests that NavigationManager::LoadIfNecessary() restores the page after
// disabling and re-enabling web usage.
TEST_F(WebStateObserverTest, DisableAndReenableWebUsage) {
  auto web_state = WebState::CreateWithStorageSession(
      WebState::CreateParams(GetBrowserState()),
      GetTestSessionStorage(test_server_->GetURL(kTestPageURL)));
  web_state->GetNavigationManager()->LoadIfNecessary();
  ASSERT_TRUE(test::WaitForWebViewContainingText(web_state.get(),
                                                 kTestSessionStoragePageText));

  web_state->SetWebUsageEnabled(false);
  web_state->SetWebUsageEnabled(true);

  // NavigationManager::LoadIfNecessary() should restore the page.
  ASSERT_FALSE(test::IsWebViewContainingText(web_state.get(),
                                             kTestSessionStoragePageText));
  web_state->GetNavigationManager()->LoadIfNecessary();
  EXPECT_TRUE(test::WaitForWebViewContainingText(web_state.get(),
                                                 kTestSessionStoragePageText));
}

// Tests successful navigation to a PDF file:// URL.
TEST_F(WebStateObserverTest, PdfFileUrlNavigation) {
  // Construct a valid file:// URL.
  base::FilePath path;
  base::PathService::Get(base::DIR_MODULE, &path);
  path = path.Append(
      FILE_PATH_LITERAL("ios/testing/data/http_server_files/testpage.pdf"));

  GURL url(url::SchemeHostPort(url::kFileScheme, std::string(), 0).Serialize());
  GURL::Replacements replacements;
  replacements.SetPathStr(path.value());
  url = url.ReplaceComponents(replacements);
  ASSERT_TRUE(url.is_valid());
  ASSERT_FALSE(url.is_empty());

  // Perform file:// URL navigation.
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), url, ui::PageTransition::PAGE_TRANSITION_TYPED, &context,
          &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(
          VerifyPdfFileUrlFinishedContext(web_state(), url, &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  web::NavigationManager::WebLoadParams params(url);
  params.transition_type = ui::PageTransition::PAGE_TRANSITION_TYPED;
  params.virtual_url =
      GURL(url::SchemeHostPort(kTestAppSpecificScheme, "foo", 0).Serialize());
  ASSERT_TRUE(LoadWithParams(params));
}

// Tests loading Data in place of a normal URL.
TEST_F(WebStateObserverTest, LoadData) {
  // Perform first navigation.
  const GURL first_url = test_server_->GetURL("/echoall");
  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  WebStatePolicyDecider::RequestInfo expected_request_info(
      ui::PageTransition::PAGE_TRANSITION_TYPED,
      /*target_main_frame=*/true, /*target_frame_is_cross_origin=*/false,
      /*has_user_gesture=*/false);
  EXPECT_CALL(*decider_, MockShouldAllowRequest(
                             _, RequestInfoMatch(expected_request_info), _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  NavigationContext* context = nullptr;
  int32_t nav_id = 0;
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyPageStartedContext(
          web_state(), first_url, ui::PageTransition::PAGE_TRANSITION_TYPED,
          &context, &nav_id));
  EXPECT_CALL(*decider_, ShouldAllowResponse(_, /*for_main_frame=*/true, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyNewPageFinishedContext(
          web_state(), first_url, kExpectedMimeType, /*content_is_html=*/true,
          &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  ASSERT_TRUE(LoadUrl(first_url));

  NSString* html = @"<html><body>foo</body></html>";
  GURL data_url("https://www.chromium.test");

  EXPECT_CALL(observer_, DidStartLoading(web_state()));
  EXPECT_CALL(*decider_, MockShouldAllowRequest(_, _, _))
      .WillOnce(
          RunOnceCallback<2>(WebStatePolicyDecider::PolicyDecision::Allow()));
  // ShouldAllowResponse is not called on loadData navigation.
  EXPECT_CALL(observer_, DidStartNavigation(web_state(), _))
      .WillOnce(VerifyDataStartedContext(
          web_state(), data_url, ui::PageTransition::PAGE_TRANSITION_TYPED,
          &context, &nav_id));
  EXPECT_CALL(observer_, DidFinishNavigation(web_state(), _))
      .WillOnce(VerifyDataFinishedContext(web_state(), data_url, "text/html",
                                          &context, &nav_id));
  EXPECT_CALL(observer_, DidStopLoading(web_state()));
  EXPECT_CALL(observer_,
              PageLoaded(web_state(), PageLoadCompletionStatus::SUCCESS));
  web_state()->LoadData([html dataUsingEncoding:NSUTF8StringEncoding],
                        @"text/html", data_url);
  EXPECT_TRUE(test::WaitForWebViewContainingText(web_state(), "foo"));
}

}  // namespace web
