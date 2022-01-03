// Copyright (c) 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/web/chrome_web_client.h"

#import <UIKit/UIKit.h>

#include <memory>

#include "base/command_line.h"
#include "base/run_loop.h"
#include "base/strings/string_split.h"
#include "base/strings/sys_string_conversions.h"
#import "base/test/ios/wait_util.h"
#include "base/test/scoped_feature_list.h"
#include "base/test/task_environment.h"
#include "base/version.h"
#include "components/captive_portal/core/captive_portal_detector.h"
#include "components/content_settings/core/browser/host_content_settings_map.h"
#include "components/lookalikes/core/lookalike_url_util.h"
#import "components/safe_browsing/ios/browser/safe_browsing_url_allow_list.h"
#include "components/security_interstitials/core/unsafe_resource.h"
#include "components/strings/grit/components_strings.h"
#include "components/version_info/version_info.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#include "ios/chrome/browser/content_settings/host_content_settings_map_factory.h"
#import "ios/chrome/browser/safe_browsing/safe_browsing_blocking_page.h"
#import "ios/chrome/browser/safe_browsing/safe_browsing_error.h"
#import "ios/chrome/browser/safe_browsing/safe_browsing_unsafe_resource_container.h"
#import "ios/chrome/browser/ssl/captive_portal_detector_tab_helper.h"
#import "ios/chrome/browser/ssl/captive_portal_detector_tab_helper_delegate.h"
#include "ios/chrome/browser/web/error_page_controller_bridge.h"
#import "ios/chrome/browser/web/error_page_util.h"
#include "ios/chrome/browser/web/features.h"
#import "ios/components/security_interstitials/ios_blocking_page_tab_helper.h"
#import "ios/components/security_interstitials/lookalikes/lookalike_url_container.h"
#import "ios/components/security_interstitials/lookalikes/lookalike_url_error.h"
#import "ios/net/protocol_handler_util.h"
#include "ios/web/common/features.h"
#import "ios/web/common/web_view_creation_util.h"
#import "ios/web/public/test/error_test_util.h"
#import "ios/web/public/test/fakes/fake_navigation_manager.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#import "ios/web/public/test/js_test_util.h"
#include "ios/web/public/test/scoped_testing_web_client.h"
#include "net/base/net_errors.h"
#include "net/http/http_status_code.h"
#include "net/ssl/ssl_info.h"
#include "net/test/cert_test_util.h"
#include "net/test/test_data_directory.h"
#include "services/network/public/mojom/fetch_api.mojom.h"
#include "services/network/test/test_url_loader_factory.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/gtest_mac.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using base::test::ios::kWaitForActionTimeout;
using base::test::ios::WaitUntilConditionOrTimeout;

namespace {
const char kTestUrl[] = "http://chromium.test";

// Error used to test PrepareErrorPage method.
NSError* CreateTestError() {
  return web::testing::CreateTestNetError([NSError
      errorWithDomain:NSURLErrorDomain
                 code:NSURLErrorNetworkConnectionLost
             userInfo:@{
               NSURLErrorFailingURLStringErrorKey :
                   base::SysUTF8ToNSString(kTestUrl)
             }]);
}
}  // namespace

class ChromeWebClientTest : public PlatformTest {
 public:
  ChromeWebClientTest() {
    browser_state_ = TestChromeBrowserState::Builder().Build();
  }

  ChromeWebClientTest(const ChromeWebClientTest&) = delete;
  ChromeWebClientTest& operator=(const ChromeWebClientTest&) = delete;

  ~ChromeWebClientTest() override = default;

  ChromeBrowserState* browser_state() { return browser_state_.get(); }

 private:
  base::test::TaskEnvironment environment_;
  std::unique_ptr<ChromeBrowserState> browser_state_;
};

TEST_F(ChromeWebClientTest, UserAgent) {
  std::vector<std::string> pieces;

  // Check if the pieces of the user agent string come in the correct order.
  ChromeWebClient web_client;
  std::string buffer = web_client.GetUserAgent(web::UserAgentType::MOBILE);

  pieces = base::SplitStringUsingSubstr(
      buffer, "Mozilla/5.0 (", base::TRIM_WHITESPACE, base::SPLIT_WANT_ALL);
  ASSERT_EQ(2u, pieces.size());
  buffer = pieces[1];
  EXPECT_EQ("", pieces[0]);

  pieces = base::SplitStringUsingSubstr(
      buffer, ") AppleWebKit/", base::TRIM_WHITESPACE, base::SPLIT_WANT_ALL);
  ASSERT_EQ(2u, pieces.size());
  buffer = pieces[1];
  std::string os_str = pieces[0];

  pieces =
      base::SplitStringUsingSubstr(buffer, " (KHTML, like Gecko) ",
                                   base::TRIM_WHITESPACE, base::SPLIT_WANT_ALL);
  ASSERT_EQ(2u, pieces.size());
  buffer = pieces[1];
  std::string webkit_version_str = pieces[0];

  pieces = base::SplitStringUsingSubstr(
      buffer, " Safari/", base::TRIM_WHITESPACE, base::SPLIT_WANT_ALL);
  ASSERT_EQ(2u, pieces.size());
  std::string product_str = pieces[0];
  std::string safari_version_str = pieces[1];

  // Not sure what can be done to better check the OS string, since it's highly
  // platform-dependent.
  EXPECT_FALSE(os_str.empty());

  EXPECT_FALSE(webkit_version_str.empty());
  EXPECT_FALSE(safari_version_str.empty());

  EXPECT_EQ(0u, product_str.find("CriOS/"));
}

// Tests that the mobile user agent has a correct Chrome version number when
// the major version is forced to be 100.
TEST_F(ChromeWebClientTest, Version100MobileUserAgent) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitWithFeatures({web::kForceMajorVersion100InUserAgent},
                                       {});

  ChromeWebClient web_client;
  std::string buffer = web_client.GetUserAgent(web::UserAgentType::MOBILE);

  std::vector<std::string> pieces = base::SplitStringUsingSubstr(
      buffer, " CriOS/", base::TRIM_WHITESPACE, base::SPLIT_WANT_ALL);
  ASSERT_EQ(2u, pieces.size());
  buffer = pieces[1];

  pieces = base::SplitStringUsingSubstr(
      buffer, " Mobile", base::TRIM_WHITESPACE, base::SPLIT_WANT_ALL);
  ASSERT_EQ(2u, pieces.size());

  base::Version version(pieces[0]);
  ASSERT_TRUE(version.IsValid());

  // Verify that the first component is 100, but the remaining components are
  // unchanged.
  EXPECT_EQ(100u, version.components()[0]);
  base::Version current_version = version_info::GetVersion();
  ASSERT_EQ(version.components().size(), current_version.components().size());
  for (size_t i = 1; i < version.components().size(); ++i) {
    EXPECT_EQ(version.components()[i], current_version.components()[i]);
  }
}

// Tests that the desktop user agent has a correct Chrome version number when
// the major version is forced to be 100.
TEST_F(ChromeWebClientTest, Version100DesktopUserAgent) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitWithFeatures({web::kForceMajorVersion100InUserAgent},
                                       {});

  ChromeWebClient web_client;
  std::string buffer = web_client.GetUserAgent(web::UserAgentType::DESKTOP);

  std::vector<std::string> pieces = base::SplitStringUsingSubstr(
      buffer, " CriOS/", base::TRIM_WHITESPACE, base::SPLIT_WANT_ALL);
  ASSERT_EQ(2u, pieces.size());
  buffer = pieces[1];

  pieces = base::SplitStringUsingSubstr(
      buffer, " Version", base::TRIM_WHITESPACE, base::SPLIT_WANT_ALL);
  ASSERT_EQ(2u, pieces.size());

  // The desktop user agent string only contains the major version number.
  std::string version_number = pieces[0];
  EXPECT_EQ("100", version_number);
}

// Tests PrepareErrorPage wth non-post, not Off The Record error.
TEST_F(ChromeWebClientTest, PrepareErrorPageNonPostNonOtr) {
  ChromeWebClient web_client;
  NSError* error = CreateTestError();
  __block bool callback_called = false;
  __block NSString* page = nil;
  base::OnceCallback<void(NSString*)> callback =
      base::BindOnce(^(NSString* error_html) {
        callback_called = true;
        page = error_html;
      });
  web::FakeWebState web_state;
  ErrorPageControllerBridge::CreateForWebState(&web_state);
  web_client.PrepareErrorPage(&web_state, GURL(kTestUrl), error,
                              /*is_post=*/false,
                              /*is_off_the_record=*/false,
                              /*info=*/absl::nullopt,
                              /*navigation_id=*/0, std::move(callback));
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForActionTimeout, ^bool {
    base::RunLoop().RunUntilIdle();
    return callback_called;
  }));
  EXPECT_NSEQ(GetErrorPage(GURL(kTestUrl), error, /*is_post=*/false,
                           /*is_off_the_record=*/false),
              page);
}

// Tests PrepareErrorPage with post, not Off The Record error.
TEST_F(ChromeWebClientTest, PrepareErrorPagePostNonOtr) {
  ChromeWebClient web_client;
  NSError* error = CreateTestError();
  __block bool callback_called = false;
  __block NSString* page = nil;
  base::OnceCallback<void(NSString*)> callback =
      base::BindOnce(^(NSString* error_html) {
        callback_called = true;
        page = error_html;
      });
  web::FakeWebState web_state;
  ErrorPageControllerBridge::CreateForWebState(&web_state);
  web_client.PrepareErrorPage(&web_state, GURL(kTestUrl), error,
                              /*is_post=*/true,
                              /*is_off_the_record=*/false,
                              /*info=*/absl::nullopt,
                              /*navigation_id=*/0, std::move(callback));
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForActionTimeout, ^bool {
    base::RunLoop().RunUntilIdle();
    return callback_called;
  }));
  EXPECT_NSEQ(GetErrorPage(GURL(kTestUrl), error, /*is_post=*/true,
                           /*is_off_the_record=*/false),
              page);
}

// Tests PrepareErrorPage with non-post, Off The Record error.
TEST_F(ChromeWebClientTest, PrepareErrorPageNonPostOtr) {
  ChromeWebClient web_client;
  NSError* error = CreateTestError();
  __block bool callback_called = false;
  __block NSString* page = nil;
  base::OnceCallback<void(NSString*)> callback =
      base::BindOnce(^(NSString* error_html) {
        callback_called = true;
        page = error_html;
      });
  web::FakeWebState web_state;
  ErrorPageControllerBridge::CreateForWebState(&web_state);
  web_client.PrepareErrorPage(&web_state, GURL(kTestUrl), error,
                              /*is_post=*/false,
                              /*is_off_the_record=*/true,
                              /*info=*/absl::nullopt,
                              /*navigation_id=*/0, std::move(callback));
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForActionTimeout, ^bool {
    base::RunLoop().RunUntilIdle();
    return callback_called;
  }));
  EXPECT_NSEQ(GetErrorPage(GURL(kTestUrl), error, /*is_post=*/false,
                           /*is_off_the_record=*/true),
              page);
}

// Tests PrepareErrorPage with post, Off The Record error.
TEST_F(ChromeWebClientTest, PrepareErrorPagePostOtr) {
  ChromeWebClient web_client;
  NSError* error = CreateTestError();
  __block bool callback_called = false;
  __block NSString* page = nil;
  base::OnceCallback<void(NSString*)> callback =
      base::BindOnce(^(NSString* error_html) {
        callback_called = true;
        page = error_html;
      });
  web::FakeWebState web_state;
  ErrorPageControllerBridge::CreateForWebState(&web_state);
  web_client.PrepareErrorPage(&web_state, GURL(kTestUrl), error,
                              /*is_post=*/true,
                              /*is_off_the_record=*/true,
                              /*info=*/absl::nullopt,
                              /*navigation_id=*/0, std::move(callback));
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForActionTimeout, ^bool {
    base::RunLoop().RunUntilIdle();
    return callback_called;
  }));
  EXPECT_NSEQ(GetErrorPage(GURL(kTestUrl), error, /*is_post=*/true,
                           /*is_off_the_record=*/true),
              page);
}

// Tests PrepareErrorPage with SSLInfo, which results in an SSL committed
// interstitial.
TEST_F(ChromeWebClientTest, PrepareErrorPageWithSSLInfo) {
  net::SSLInfo info;
  info.cert =
      net::ImportCertFromFile(net::GetTestCertsDirectory(), "ok_cert.pem");
  info.is_fatal_cert_error = false;
  info.cert_status = net::CERT_STATUS_COMMON_NAME_INVALID;
  absl::optional<net::SSLInfo> ssl_info =
      absl::make_optional<net::SSLInfo>(info);
  ChromeWebClient web_client;
  NSError* error =
      [NSError errorWithDomain:NSURLErrorDomain
                          code:NSURLErrorServerCertificateHasUnknownRoot
                      userInfo:nil];
  __block bool callback_called = false;
  __block NSString* page = nil;
  base::OnceCallback<void(NSString*)> callback =
      base::BindOnce(^(NSString* error_html) {
        callback_called = true;
        page = error_html;
      });
  web::FakeWebState web_state;
  security_interstitials::IOSBlockingPageTabHelper::CreateForWebState(
      &web_state);

  // Use a test URLLoaderFactory so that the captive portal detector doesn't
  // make an actual network request.
  network::TestURLLoaderFactory test_loader_factory;
  test_loader_factory.AddResponse(
      captive_portal::CaptivePortalDetector::kDefaultURL, "",
      net::HTTP_NO_CONTENT);
  id captive_portal_detector_tab_helper_delegate = [OCMockObject
      mockForProtocol:@protocol(CaptivePortalDetectorTabHelperDelegate)];
  CaptivePortalDetectorTabHelper::CreateForWebState(
      &web_state, captive_portal_detector_tab_helper_delegate,
      &test_loader_factory);

  web_state.SetBrowserState(browser_state());
  web_client.PrepareErrorPage(&web_state, GURL(kTestUrl), error,
                              /*is_post=*/false,
                              /*is_off_the_record=*/false,
                              /*info=*/ssl_info,
                              /*navigation_id=*/0, std::move(callback));
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForActionTimeout, ^bool {
    base::RunLoop().RunUntilIdle();
    return callback_called;
  }));
  NSString* error_string = base::SysUTF8ToNSString(
      net::ErrorToShortString(net::ERR_CERT_COMMON_NAME_INVALID));
  EXPECT_TRUE([page containsString:error_string]);
}

// Tests PrepareErrorPage for a safe browsing error, which results in a
// committed safe browsing interstitial.
TEST_F(ChromeWebClientTest, PrepareErrorPageForSafeBrowsingError) {
  // Store an unsafe resource in |web_state|'s container.
  web::FakeWebState web_state;
  web_state.SetBrowserState(browser_state());
  SafeBrowsingUrlAllowList::CreateForWebState(&web_state);
  SafeBrowsingUnsafeResourceContainer::CreateForWebState(&web_state);
  security_interstitials::IOSBlockingPageTabHelper::CreateForWebState(
      &web_state);

  security_interstitials::UnsafeResource resource;
  resource.threat_type = safe_browsing::SB_THREAT_TYPE_URL_PHISHING;
  resource.url = GURL("http://www.chromium.test");
  resource.request_destination = network::mojom::RequestDestination::kDocument;
  resource.web_state_getter = web_state.CreateDefaultGetter();
  SafeBrowsingUrlAllowList::FromWebState(&web_state)
      ->AddPendingUnsafeNavigationDecision(resource.url, resource.threat_type);
  SafeBrowsingUnsafeResourceContainer::FromWebState(&web_state)
      ->StoreMainFrameUnsafeResource(resource);

  NSError* error = [NSError errorWithDomain:kSafeBrowsingErrorDomain
                                       code:kUnsafeResourceErrorCode
                                   userInfo:nil];
  __block bool callback_called = false;
  __block NSString* page = nil;
  base::OnceCallback<void(NSString*)> callback =
      base::BindOnce(^(NSString* error_html) {
        callback_called = true;
        page = error_html;
      });

  ChromeWebClient web_client;
  web_client.PrepareErrorPage(&web_state, GURL(kTestUrl), error,
                              /*is_post=*/false,
                              /*is_off_the_record=*/false,
                              /*info=*/absl::optional<net::SSLInfo>(),
                              /*navigation_id=*/0, std::move(callback));

  EXPECT_TRUE(callback_called);
  NSString* error_string = l10n_util::GetNSString(IDS_PHISHING_V4_HEADING);
  EXPECT_TRUE([page containsString:error_string]);
}

// Tests PrepareErrorPage for a lookalike error, which results in a
// committed lookalike interstitial.
TEST_F(ChromeWebClientTest, PrepareErrorPageForLookalikeUrlError) {
  web::FakeWebState web_state;
  web_state.SetBrowserState(browser_state());
  LookalikeUrlContainer::CreateForWebState(&web_state);
  security_interstitials::IOSBlockingPageTabHelper::CreateForWebState(
      &web_state);
  auto navigation_manager = std::make_unique<web::FakeNavigationManager>();
  web_state.SetNavigationManager(std::move(navigation_manager));

  LookalikeUrlContainer::FromWebState(&web_state)
      ->SetLookalikeUrlInfo(GURL("https://www.safe.test"), GURL(kTestUrl),
                            LookalikeUrlMatchType::kSkeletonMatchTop5k);

  NSError* error = [NSError errorWithDomain:kLookalikeUrlErrorDomain
                                       code:kLookalikeUrlErrorCode
                                   userInfo:nil];
  __block bool callback_called = false;
  __block NSString* page = nil;
  base::OnceCallback<void(NSString*)> callback =
      base::BindOnce(^(NSString* error_html) {
        callback_called = true;
        page = error_html;
      });

  ChromeWebClient web_client;
  web_client.PrepareErrorPage(&web_state, GURL(kTestUrl), error,
                              /*is_post=*/false,
                              /*is_off_the_record=*/false,
                              /*info=*/absl::optional<net::SSLInfo>(),
                              /*navigation_id=*/0, std::move(callback));

  EXPECT_TRUE(callback_called);
  NSString* error_string =
      l10n_util::GetNSString(IDS_LOOKALIKE_URL_PRIMARY_PARAGRAPH);
  EXPECT_TRUE([page containsString:error_string])
      << base::SysNSStringToUTF8(page);
}

// Tests PrepareErrorPage for a lookalike error with no suggested URL,
// which results in a committed lookalike interstitial that has a 'Close page'
// button instead of 'Back to safety' (when there is no back item).
TEST_F(ChromeWebClientTest, PrepareErrorPageForLookalikeUrlErrorNoSuggestion) {
  web::FakeWebState web_state;
  web_state.SetBrowserState(browser_state());
  LookalikeUrlContainer::CreateForWebState(&web_state);
  security_interstitials::IOSBlockingPageTabHelper::CreateForWebState(
      &web_state);
  auto navigation_manager = std::make_unique<web::FakeNavigationManager>();
  web_state.SetNavigationManager(std::move(navigation_manager));

  LookalikeUrlContainer::FromWebState(&web_state)
      ->SetLookalikeUrlInfo(GURL(""), GURL(kTestUrl),
                            LookalikeUrlMatchType::kSkeletonMatchTop5k);

  NSError* error = [NSError errorWithDomain:kLookalikeUrlErrorDomain
                                       code:kLookalikeUrlErrorCode
                                   userInfo:nil];
  __block bool callback_called = false;
  __block NSString* page = nil;
  base::OnceCallback<void(NSString*)> callback =
      base::BindOnce(^(NSString* error_html) {
        callback_called = true;
        page = error_html;
      });

  ChromeWebClient web_client;
  web_client.PrepareErrorPage(&web_state, GURL(kTestUrl), error,
                              /*is_post=*/false,
                              /*is_off_the_record=*/false,
                              /*info=*/absl::optional<net::SSLInfo>(),
                              /*navigation_id=*/0, std::move(callback));

  EXPECT_TRUE(callback_called);
  NSString* close_page_string =
      l10n_util::GetNSString(IDS_LOOKALIKE_URL_CLOSE_PAGE);
  NSString* back_to_safety_string =
      l10n_util::GetNSString(IDS_LOOKALIKE_URL_BACK_TO_SAFETY);
  EXPECT_TRUE([page containsString:close_page_string])
      << base::SysNSStringToUTF8(page);
  EXPECT_FALSE([page containsString:back_to_safety_string])
      << base::SysNSStringToUTF8(page);
}

// Tests the default user agent for different views.
TEST_F(ChromeWebClientTest, DefaultUserAgent) {
  ChromeWebClient web_client;
  web::FakeWebState web_state;
  web_state.SetBrowserState(browser_state());

  scoped_refptr<HostContentSettingsMap> settings_map(
      ios::HostContentSettingsMapFactory::GetForBrowserState(browser_state()));
  settings_map->SetContentSettingCustomScope(
      ContentSettingsPattern::Wildcard(), ContentSettingsPattern::Wildcard(),
      ContentSettingsType::REQUEST_DESKTOP_SITE, CONTENT_SETTING_BLOCK);

  EXPECT_EQ(web::UserAgentType::MOBILE,
            web_client.GetDefaultUserAgent(&web_state, GURL()));

  settings_map->SetContentSettingCustomScope(
      ContentSettingsPattern::Wildcard(), ContentSettingsPattern::Wildcard(),
      ContentSettingsType::REQUEST_DESKTOP_SITE, CONTENT_SETTING_ALLOW);

  EXPECT_EQ(web::UserAgentType::DESKTOP,
            web_client.GetDefaultUserAgent(&web_state, GURL()));
}
