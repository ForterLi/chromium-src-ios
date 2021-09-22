// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/web/image_fetch/image_fetch_tab_helper.h"

#include "base/base64.h"
#include "base/bind.h"
#include "base/json/string_escape.h"
#include "base/metrics/histogram_macros.h"
#include "base/strings/stringprintf.h"
#include "base/strings/utf_string_conversions.h"
#include "base/task/post_task.h"
#include "base/values.h"
#include "components/image_fetcher/ios/ios_image_data_fetcher_wrapper.h"
#include "ios/chrome/browser/web/image_fetch/image_fetch_java_script_feature.h"
#include "ios/web/common/referrer_util.h"
#include "ios/web/public/browser_state.h"
#import "ios/web/public/navigation/navigation_context.h"
#include "ios/web/public/thread/web_task_traits.h"
#include "ios/web/public/thread/web_thread.h"
#include "services/network/public/cpp/shared_url_loader_factory.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

const char kUmaGetImageDataByJsResult[] =
    "ContextMenu.iOS.GetImageDataByJsResult";

namespace {
// Key for image_fetcher
const char kImageFetcherKeyName[] = "0";
// Timeout for GetImageDataByJs in milliseconds.
const int kGetImageDataByJsTimeout = 300;

// Wrapper class for image_fetcher::IOSImageDataFetcherWrapper. ImageFetcher is
// attached to web::BrowserState instead of web::WebState, because if a user
// closes the tab immediately after Copy/Save image, the web::WebState will be
// destroyed thus fail the download.
class ImageFetcher : public image_fetcher::IOSImageDataFetcherWrapper,
                     public base::SupportsUserData::Data {
 public:
  ImageFetcher(const ImageFetcher&) = delete;
  ImageFetcher& operator=(const ImageFetcher&) = delete;

  ~ImageFetcher() override = default;

  ImageFetcher(
      scoped_refptr<network::SharedURLLoaderFactory> url_loader_factory)
      : image_fetcher::IOSImageDataFetcherWrapper(url_loader_factory) {}

  static ImageFetcher* FromBrowserState(web::BrowserState* browser_state) {
    if (!browser_state->GetUserData(&kImageFetcherKeyName)) {
      browser_state->SetUserData(
          &kImageFetcherKeyName,
          std::make_unique<ImageFetcher>(
              browser_state->GetSharedURLLoaderFactory()));
    }
    return static_cast<ImageFetcher*>(
        browser_state->GetUserData(&kImageFetcherKeyName));
  }
};
}

ImageFetchTabHelper::ImageFetchTabHelper(web::WebState* web_state)
    : web_state_(web_state), weak_ptr_factory_(this) {
  web_state->AddObserver(this);
}

ImageFetchTabHelper::~ImageFetchTabHelper() = default;

void ImageFetchTabHelper::DidStartNavigation(
    web::WebState* web_state,
    web::NavigationContext* navigation_context) {
  if (navigation_context->IsSameDocument()) {
    return;
  }
  for (auto&& pair : js_callbacks_)
    std::move(pair.second).Run(nullptr);
  js_callbacks_.clear();
}

void ImageFetchTabHelper::WebStateDestroyed(web::WebState* web_state) {
  for (auto&& pair : js_callbacks_)
    std::move(pair.second).Run(nullptr);
  web_state->RemoveObserver(this);
  web_state_ = nullptr;
}

void ImageFetchTabHelper::GetImageData(const GURL& url,
                                       const web::Referrer& referrer,
                                       ImageDataCallback callback) {
  // |this| is captured into the callback of GetImageDataByJs, which will always
  // be invoked before the |this| is destroyed, so it's safe.
  GetImageDataByJs(
      url, base::TimeDelta::FromMilliseconds(kGetImageDataByJsTimeout),
      base::BindOnce(&ImageFetchTabHelper::JsCallbackOfGetImageData,
                     base::Unretained(this), url, referrer, callback));
}

void ImageFetchTabHelper::JsCallbackOfGetImageData(
    const GURL& url,
    const web::Referrer& referrer,
    ImageDataCallback callback,
    const std::string* data) {
  if (data) {
    callback([NSData dataWithBytes:data->c_str() length:data->size()]);
    return;
  }
  ImageFetcher::FromBrowserState(web_state_->GetBrowserState())
      ->FetchImageDataWebpDecoded(
          url,
          ^(NSData* data, const image_fetcher::RequestMetadata& metadata) {
            callback(data);
          },
          web::ReferrerHeaderValueForNavigation(url, referrer),
          web::PolicyForNavigation(url, referrer), /*send_cookies=*/true);
}

void ImageFetchTabHelper::GetImageDataByJs(const GURL& url,
                                           base::TimeDelta timeout,
                                           JsCallback&& callback) {
  ++call_id_;
  DCHECK_EQ(js_callbacks_.count(call_id_), 0UL);
  js_callbacks_.insert({call_id_, std::move(callback)});

  base::PostDelayedTask(
      FROM_HERE, {web::WebThread::UI},
      base::BindRepeating(&ImageFetchTabHelper::OnJsTimeout,
                          weak_ptr_factory_.GetWeakPtr(), call_id_),
      timeout);

  ImageFetchJavaScriptFeature::GetInstance()->GetImageData(web_state_, call_id_,
                                                           url);
}

void ImageFetchTabHelper::RecordGetImageDataByJsResult(
    ContextMenuGetImageDataByJsResult result) {
  UMA_HISTOGRAM_ENUMERATION(kUmaGetImageDataByJsResult, result);
}

void ImageFetchTabHelper::HandleJsSuccess(int call_id,
                                          std::string& decoded_data,
                                          std::string& from) {
  if (!js_callbacks_.count(call_id)) {
    return;
  }
  JsCallback callback = std::move(js_callbacks_[call_id]);
  js_callbacks_.erase(call_id);

  DCHECK(!decoded_data.empty());
  std::move(callback).Run(&decoded_data);

  if (from == "canvas") {
    RecordGetImageDataByJsResult(
        ContextMenuGetImageDataByJsResult::kCanvasSucceed);
  } else if (from == "xhr") {
    RecordGetImageDataByJsResult(
        ContextMenuGetImageDataByJsResult::kXMLHttpRequestSucceed);
  }
}

void ImageFetchTabHelper::HandleJsFailure(int call_id) {
  if (!js_callbacks_.count(call_id)) {
    return;
  }
  JsCallback callback = std::move(js_callbacks_[call_id]);
  js_callbacks_.erase(call_id);

  std::move(callback).Run(nullptr);
  RecordGetImageDataByJsResult(ContextMenuGetImageDataByJsResult::kFail);
}

void ImageFetchTabHelper::OnJsTimeout(int call_id) {
  if (js_callbacks_.count(call_id)) {
    JsCallback callback = std::move(js_callbacks_[call_id]);
    js_callbacks_.erase(call_id);
    std::move(callback).Run(nullptr);
    RecordGetImageDataByJsResult(ContextMenuGetImageDataByJsResult::kTimeout);
  }
}

WEB_STATE_USER_DATA_KEY_IMPL(ImageFetchTabHelper)
