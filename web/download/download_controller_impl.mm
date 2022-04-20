// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/download/download_controller_impl.h"

#include "base/strings/sys_string_conversions.h"
#import "ios/web/download/data_url_download_task.h"
#import "ios/web/download/download_native_task_bridge.h"
#import "ios/web/download/download_native_task_impl.h"
#import "ios/web/download/download_session_cookie_storage.h"
#import "ios/web/download/download_session_task_impl.h"
#include "ios/web/public/browser_state.h"
#import "ios/web/public/download/download_controller_delegate.h"
#import "net/base/mac/url_conversions.h"
#include "net/http/http_request_headers.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
const char kDownloadControllerKey = 0;
}  // namespace

namespace web {

// static
DownloadController* DownloadController::FromBrowserState(
    BrowserState* browser_state) {
  DCHECK(browser_state);
  if (!browser_state->GetUserData(&kDownloadControllerKey)) {
    browser_state->SetUserData(&kDownloadControllerKey,
                               std::make_unique<DownloadControllerImpl>());
  }
  return static_cast<DownloadControllerImpl*>(
      browser_state->GetUserData(&kDownloadControllerKey));
}

DownloadControllerImpl::DownloadControllerImpl() = default;

DownloadControllerImpl::~DownloadControllerImpl() {
  DCHECK_CALLED_ON_VALID_SEQUENCE(my_sequence_checker_);
  for (DownloadTaskImpl* task : alive_tasks_)
    task->ShutDown();

  if (delegate_)
    delegate_->OnDownloadControllerDestroyed(this);

  DCHECK(!delegate_);
}

void DownloadControllerImpl::CreateDownloadTask(
    WebState* web_state,
    NSString* identifier,
    const GURL& original_url,
    NSString* http_method,
    const std::string& content_disposition,
    int64_t total_bytes,
    const std::string& mime_type) {
  DCHECK_CALLED_ON_VALID_SEQUENCE(my_sequence_checker_);
  if (!delegate_)
    return;

  std::unique_ptr<DownloadTaskImpl> task;
  if (original_url.SchemeIs(url::kDataScheme)) {
    task = std::make_unique<DataUrlDownloadTask>(
        web_state, original_url, http_method, content_disposition, total_bytes,
        mime_type, identifier, this);
  } else {
    task = std::make_unique<DownloadSessionTaskImpl>(
        web_state, original_url, http_method, content_disposition, total_bytes,
        mime_type, identifier, this);
  }
  DCHECK(task);

  alive_tasks_.insert(task.get());
  delegate_->OnDownloadCreated(this, web_state, std::move(task));
}

void DownloadControllerImpl::CreateNativeDownloadTask(
    WebState* web_state,
    NSString* identifier,
    const GURL& original_url,
    NSString* http_method,
    const std::string& content_disposition,
    int64_t total_bytes,
    const std::string& mime_type,
    DownloadNativeTaskBridge* download) API_AVAILABLE(ios(15)) {
  DCHECK_CALLED_ON_VALID_SEQUENCE(my_sequence_checker_);
  if (!delegate_) {
    [download cancel];
    return;
  }

  auto task = std::make_unique<DownloadNativeTaskImpl>(
      web_state, original_url, http_method, content_disposition, total_bytes,
      mime_type, identifier, download, this);
  alive_tasks_.insert(task.get());
  delegate_->OnDownloadCreated(this, web_state, std::move(task));
}

void DownloadControllerImpl::SetDelegate(DownloadControllerDelegate* delegate) {
  DCHECK_CALLED_ON_VALID_SEQUENCE(my_sequence_checker_);
  delegate_ = delegate;
}

DownloadControllerDelegate* DownloadControllerImpl::GetDelegate() const {
  DCHECK_CALLED_ON_VALID_SEQUENCE(my_sequence_checker_);
  return delegate_;
}

void DownloadControllerImpl::OnTaskDestroyed(DownloadTaskImpl* task) {
  DCHECK_CALLED_ON_VALID_SEQUENCE(my_sequence_checker_);
  auto it = alive_tasks_.find(task);
  DCHECK(it != alive_tasks_.end());
  alive_tasks_.erase(it);
}

}  // namespace web
