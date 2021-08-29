// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/js_messaging/web_frames_manager_java_script_feature.h"

#import "base/strings/string_number_conversions.h"
#import "base/strings/sys_string_conversions.h"
#import "ios/web/js_messaging/crw_wk_script_message_router.h"
#include "ios/web/js_messaging/web_frame_impl.h"
#import "ios/web/js_messaging/web_view_web_state_map.h"
#include "ios/web/public/test/fakes/fake_web_frame.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#import "ios/web/public/test/web_test_with_web_state.h"
#import "ios/web/web_state/web_state_impl.h"
#include "testing/gtest/include/gtest/gtest.h"
#import "third_party/ocmock/OCMock/OCMock.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// A base64 encoded sample key.
const char kFrameKey[] = "R7lsXtR74c6R9A9k691gUQ8JAd0be+w//Lntgcbjwrc=";

// Message command sent when a frame becomes available.
NSString* const kFrameBecameAvailableMessageName = @"FrameBecameAvailable";
// Message command sent when a frame is unloading.
NSString* const kFrameBecameUnavailableMessageName = @"FrameBecameUnavailable";

}  // namespace

namespace web {

class WebFramesManagerJavaScriptFeatureTest : public WebTestWithWebState {
 protected:
  WebFramesManagerJavaScriptFeatureTest()
      : user_content_controller_([[WKUserContentController alloc] init]),
        router_([[CRWWKScriptMessageRouter alloc]
            initWithUserContentController:user_content_controller_]),
        web_view_(OCMClassMock([WKWebView class])),
        main_frame_(web::FakeWebFrame::Create(kMainFakeFrameId,
                                              /*is_main_frame=*/true,
                                              GURL("https://www.main.test"))),
        frame_1_(web::FakeWebFrame::Create(kChildFakeFrameId,
                                           /*is_main_frame=*/false,
                                           GURL("https://www.frame1.test"))),
        frame_2_(web::FakeWebFrame::Create(kChildFakeFrameId2,
                                           /*is_main_frame=*/false,
                                           GURL("https://www.frame2.test"))) {}

  // Sends a JS message of a newly loaded web frame to |router_| which will
  // dispatch it to |frames_manager_|.
  void SendFrameBecameAvailableMessage(const FakeWebFrame* web_frame) {
    // Mock WKSecurityOrigin.
    WKSecurityOrigin* security_origin = OCMClassMock([WKSecurityOrigin class]);
    OCMStub([security_origin host])
        .andReturn(
            base::SysUTF8ToNSString(web_frame->GetSecurityOrigin().host()));
    OCMStub([security_origin port])
        .andReturn(web_frame->GetSecurityOrigin().EffectiveIntPort());
    OCMStub([security_origin protocol])
        .andReturn(
            base::SysUTF8ToNSString(web_frame->GetSecurityOrigin().scheme()));

    // Mock WKFrameInfo.
    WKFrameInfo* frame_info = OCMClassMock([WKFrameInfo class]);
    OCMStub([frame_info isMainFrame]).andReturn(web_frame->IsMainFrame());
    OCMStub([frame_info securityOrigin]).andReturn(security_origin);

    // Mock WKScriptMessage for "FrameBecameAvailable" message.
    NSDictionary* body = @{
      @"crwFrameId" : base::SysUTF8ToNSString(web_frame->GetFrameId()),
      @"crwFrameKey" : base::SysUTF8ToNSString(kFrameKey),
      @"crwFrameLastReceivedMessageId" : @-1,
    };
    WKScriptMessage* message = OCMClassMock([WKScriptMessage class]);
    OCMStub([message body]).andReturn(body);
    OCMStub([message frameInfo]).andReturn(frame_info);
    OCMStub([message name]).andReturn(kFrameBecameAvailableMessageName);
    OCMStub([message webView]).andReturn(web_view_);

    WebFramesManagerJavaScriptFeature::FromBrowserState(GetBrowserState())
        ->FrameAvailableMessageReceived(message);
  }

  // Sends a JS message of a newly unloaded web frame to |router_| which will
  // dispatch it to |frames_manager_|.
  void SendFrameBecameUnavailableMessage(const FakeWebFrame* web_frame) {
    // Mock WKSecurityOrigin.
    WKSecurityOrigin* security_origin = OCMClassMock([WKSecurityOrigin class]);
    OCMStub([security_origin host])
        .andReturn(
            base::SysUTF8ToNSString(web_frame->GetSecurityOrigin().host()));
    OCMStub([security_origin port])
        .andReturn(web_frame->GetSecurityOrigin().EffectiveIntPort());
    OCMStub([security_origin protocol])
        .andReturn(
            base::SysUTF8ToNSString(web_frame->GetSecurityOrigin().scheme()));

    // Mock WKFrameInfo.
    WKFrameInfo* frame_info = OCMClassMock([WKFrameInfo class]);
    OCMStub([frame_info isMainFrame]).andReturn(web_frame->IsMainFrame());
    OCMStub([frame_info securityOrigin]).andReturn(security_origin);

    // Mock WKScriptMessage for "FrameBecameUnavailable" message.
    WKScriptMessage* message = OCMClassMock([WKScriptMessage class]);
    OCMStub([message body])
        .andReturn(base::SysUTF8ToNSString(web_frame->GetFrameId()));
    OCMStub([message frameInfo]).andReturn(frame_info);
    OCMStub([message name]).andReturn(kFrameBecameUnavailableMessageName);
    OCMStub([message webView]).andReturn(web_view_);

    WebFramesManagerJavaScriptFeature::FromBrowserState(GetBrowserState())
        ->FrameUnavailableMessageReceived(message);
  }

  WebFramesManagerImpl& GetWebFramesManager() {
    WebStateImpl* web_state_impl = static_cast<WebStateImpl*>(web_state());
    return web_state_impl->GetWebFramesManagerImpl();
  }

  void SetUp() override {
    WebTestWithWebState::SetUp();
    WebViewWebStateMap::FromBrowserState(GetBrowserState())
        ->SetAssociatedWebViewForWebState(web_view_, web_state());
  }

  WKUserContentController* user_content_controller_ = nil;
  CRWWKScriptMessageRouter* router_ = nil;
  WKWebView* web_view_ = nil;
  std::unique_ptr<const FakeWebFrame> main_frame_;
  std::unique_ptr<const FakeWebFrame> frame_1_;
  std::unique_ptr<const FakeWebFrame> frame_2_;
};

// Tests that a WebFrame can not be registered with a malformed frame id.
TEST_F(WebFramesManagerJavaScriptFeatureTest, WebFrameWithInvalidId) {
  auto frame_with_invalid_id = FakeWebFrame::Create(
      kInvalidFrameId,
      /*is_main_frame=*/true, GURL("https://www.main.test"));
  SendFrameBecameAvailableMessage(frame_with_invalid_id.get());

  EXPECT_EQ(0ul, GetWebFramesManager().GetAllWebFrames().size());
}

// Tests multiple web frames construction/destruction.
TEST_F(WebFramesManagerJavaScriptFeatureTest, MultipleWebFrame) {
  // Add main frame.
  SendFrameBecameAvailableMessage(main_frame_.get());
  EXPECT_EQ(1ul, GetWebFramesManager().GetAllWebFrames().size());
  // Check main frame.
  WebFrame* main_frame = GetWebFramesManager().GetMainWebFrame();
  WebFrame* main_frame_by_id =
      GetWebFramesManager().GetFrameWithId(main_frame_->GetFrameId());
  ASSERT_TRUE(main_frame);
  EXPECT_EQ(main_frame, main_frame_by_id);
  EXPECT_TRUE(main_frame->IsMainFrame());
  EXPECT_EQ(main_frame_->GetSecurityOrigin(), main_frame->GetSecurityOrigin());

  // Add frame 1.
  SendFrameBecameAvailableMessage(frame_1_.get());
  EXPECT_EQ(2ul, GetWebFramesManager().GetAllWebFrames().size());
  // Check main frame.
  main_frame = GetWebFramesManager().GetMainWebFrame();
  main_frame_by_id =
      GetWebFramesManager().GetFrameWithId(main_frame_->GetFrameId());
  ASSERT_TRUE(main_frame);
  EXPECT_EQ(main_frame, main_frame_by_id);
  EXPECT_TRUE(main_frame->IsMainFrame());
  EXPECT_EQ(main_frame_->GetSecurityOrigin(), main_frame->GetSecurityOrigin());
  // Check frame 1.
  WebFrame* frame_1 =
      GetWebFramesManager().GetFrameWithId(frame_1_->GetFrameId());
  ASSERT_TRUE(frame_1);
  EXPECT_FALSE(frame_1->IsMainFrame());
  EXPECT_EQ(frame_1_->GetSecurityOrigin(), frame_1->GetSecurityOrigin());

  // Add frame 2.
  SendFrameBecameAvailableMessage(frame_2_.get());
  EXPECT_EQ(3ul, GetWebFramesManager().GetAllWebFrames().size());
  // Check main frame.
  main_frame = GetWebFramesManager().GetMainWebFrame();
  main_frame_by_id =
      GetWebFramesManager().GetFrameWithId(main_frame_->GetFrameId());
  ASSERT_TRUE(main_frame);
  EXPECT_EQ(main_frame, main_frame_by_id);
  EXPECT_TRUE(main_frame->IsMainFrame());
  EXPECT_EQ(main_frame_->GetSecurityOrigin(), main_frame->GetSecurityOrigin());
  // Check frame 1.
  frame_1 = GetWebFramesManager().GetFrameWithId(frame_1_->GetFrameId());
  ASSERT_TRUE(frame_1);
  EXPECT_FALSE(frame_1->IsMainFrame());
  EXPECT_EQ(frame_1_->GetSecurityOrigin(), frame_1->GetSecurityOrigin());
  // Check frame 2.
  WebFrame* frame_2 =
      GetWebFramesManager().GetFrameWithId(frame_2_->GetFrameId());
  ASSERT_TRUE(frame_2);
  EXPECT_FALSE(frame_2->IsMainFrame());
  EXPECT_EQ(frame_2_->GetSecurityOrigin(), frame_2->GetSecurityOrigin());

  // Remove frame 1.
  SendFrameBecameUnavailableMessage(frame_1_.get());
  EXPECT_EQ(2ul, GetWebFramesManager().GetAllWebFrames().size());
  // Check main frame.
  main_frame = GetWebFramesManager().GetMainWebFrame();
  main_frame_by_id =
      GetWebFramesManager().GetFrameWithId(main_frame_->GetFrameId());
  ASSERT_TRUE(main_frame);
  EXPECT_EQ(main_frame, main_frame_by_id);
  EXPECT_TRUE(main_frame->IsMainFrame());
  EXPECT_EQ(main_frame_->GetSecurityOrigin(), main_frame->GetSecurityOrigin());
  // Check frame 1.
  frame_1 = GetWebFramesManager().GetFrameWithId(frame_1_->GetFrameId());
  EXPECT_FALSE(frame_1);
  // Check frame 2.
  frame_2 = GetWebFramesManager().GetFrameWithId(frame_2_->GetFrameId());
  ASSERT_TRUE(frame_2);
  EXPECT_FALSE(frame_2->IsMainFrame());
  EXPECT_EQ(frame_2_->GetSecurityOrigin(), frame_2->GetSecurityOrigin());

  // Remove main frame.
  SendFrameBecameUnavailableMessage(main_frame_.get());
  EXPECT_EQ(1ul, GetWebFramesManager().GetAllWebFrames().size());
  // Check main frame.
  main_frame = GetWebFramesManager().GetMainWebFrame();
  main_frame_by_id =
      GetWebFramesManager().GetFrameWithId(main_frame_->GetFrameId());
  EXPECT_FALSE(main_frame);
  EXPECT_FALSE(main_frame_by_id);
  // Check frame 1.
  frame_1 = GetWebFramesManager().GetFrameWithId(frame_1_->GetFrameId());
  EXPECT_FALSE(frame_1);
  // Check frame 2.
  frame_2 = GetWebFramesManager().GetFrameWithId(frame_2_->GetFrameId());
  ASSERT_TRUE(frame_2);
  EXPECT_FALSE(frame_2->IsMainFrame());
  EXPECT_EQ(frame_2_->GetSecurityOrigin(), frame_2->GetSecurityOrigin());

  // Remove frame 2.
  SendFrameBecameUnavailableMessage(frame_2_.get());
  EXPECT_EQ(0ul, GetWebFramesManager().GetAllWebFrames().size());
  // Check main frame.
  main_frame = GetWebFramesManager().GetMainWebFrame();
  main_frame_by_id =
      GetWebFramesManager().GetFrameWithId(main_frame_->GetFrameId());
  EXPECT_FALSE(main_frame);
  EXPECT_FALSE(main_frame_by_id);
  // Check frame 1.
  frame_1 = GetWebFramesManager().GetFrameWithId(frame_1_->GetFrameId());
  EXPECT_FALSE(frame_1);
  // Check frame 2.
  frame_2 = GetWebFramesManager().GetFrameWithId(frame_2_->GetFrameId());
  EXPECT_FALSE(frame_2);
}

// Tests that WebFramesManagerImpl will ignore JS messages from previous
// WKWebView after WebViewWebStateMap is updated with a new WKWebView.
TEST_F(WebFramesManagerJavaScriptFeatureTest, OnWebViewUpdated) {
  SendFrameBecameAvailableMessage(main_frame_.get());
  SendFrameBecameAvailableMessage(frame_1_.get());
  EXPECT_EQ(2ul, GetWebFramesManager().GetAllWebFrames().size());

  // Update the WKWebView associated with web_state().
  WKWebView* web_view_2 = OCMClassMock([WKWebView class]);
  WebViewWebStateMap::FromBrowserState(GetBrowserState())
      ->SetAssociatedWebViewForWebState(web_view_2, web_state());
  WebStateImpl* web_state_impl = static_cast<WebStateImpl*>(web_state());
  web_state_impl->RemoveAllWebFrames();

  // Send JS message of loaded/unloaded web frames in previous WKWebView (i.e.
  // web_view_). |frames_manager_| should have unregistered JS message handlers
  // for |web_view_| and removed all web frames, so no web frame should be
  // added.
  SendFrameBecameAvailableMessage(frame_1_.get());
  EXPECT_EQ(0ul, GetWebFramesManager().GetAllWebFrames().size());
  SendFrameBecameAvailableMessage(frame_2_.get());
  EXPECT_EQ(0ul, GetWebFramesManager().GetAllWebFrames().size());
  SendFrameBecameUnavailableMessage(frame_1_.get());
  EXPECT_EQ(0ul, GetWebFramesManager().GetAllWebFrames().size());
}

}  // namespace web