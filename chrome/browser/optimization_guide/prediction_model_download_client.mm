// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/optimization_guide/prediction_model_download_client.h"

#include "base/bind.h"
#include "base/metrics/histogram_macros_local.h"
#include "base/threading/sequenced_task_runner_handle.h"
#include "components/download/public/background_service/download_metadata.h"
#include "components/optimization_guide/core/prediction_manager.h"
#include "components/optimization_guide/core/prediction_model_download_manager.h"
#include "ios/chrome/browser/optimization_guide/optimization_guide_service.h"
#include "ios/chrome/browser/optimization_guide/optimization_guide_service_factory.h"
#include "services/network/public/cpp/resource_request_body.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace optimization_guide {

namespace {

// Parses the optimization target from |custom_data|.
absl::optional<proto::OptimizationTarget> ParseOptimizationTarget(
    const download::DownloadParams::CustomData& custom_data) {
  const auto target_it =
      custom_data.find(kPredictionModelOptimizationTargetCustomDataKey);
  if (target_it == custom_data.end()) {
    return absl::nullopt;
  }
  proto::OptimizationTarget optimization_target;
  if (!proto::OptimizationTarget_Parse(target_it->second,
                                       &optimization_target)) {
    return absl::nullopt;
  }
  return optimization_target;
}

}  // namespace

PredictionModelDownloadClient::PredictionModelDownloadClient(
    ChromeBrowserState* browser_state)
    : browser_state_(browser_state) {}

PredictionModelDownloadClient::~PredictionModelDownloadClient() = default;

PredictionModelDownloadManager*
PredictionModelDownloadClient::GetPredictionModelDownloadManager() {
  OptimizationGuideService* optimization_guide_service =
      OptimizationGuideServiceFactory::GetForBrowserState(browser_state_);
  if (!optimization_guide_service)
    return nullptr;
  PredictionManager* prediction_manager =
      optimization_guide_service->GetPredictionManager();
  if (!prediction_manager)
    return nullptr;
  return prediction_manager->prediction_model_download_manager();
}

void PredictionModelDownloadClient::OnServiceInitialized(
    bool state_lost,
    const std::vector<download::DownloadMetaData>& downloads) {
  PredictionModelDownloadManager* download_manager =
      GetPredictionModelDownloadManager();
  if (!download_manager)
    return;

  std::set<std::string> outstanding_download_guids;
  std::map<std::string, base::FilePath> successful_downloads;
  for (const auto& download : downloads) {
    if (!download.completion_info) {
      outstanding_download_guids.emplace(download.guid);
      continue;
    }

    successful_downloads.emplace(download.guid, download.completion_info->path);
  }

  download_manager->OnDownloadServiceReady(outstanding_download_guids,
                                           successful_downloads);
}

void PredictionModelDownloadClient::OnServiceUnavailable() {
  PredictionModelDownloadManager* download_manager =
      GetPredictionModelDownloadManager();
  if (download_manager)
    download_manager->OnDownloadServiceUnavailable();
}

void PredictionModelDownloadClient::OnDownloadStarted(
    const std::string& guid,
    const std::vector<GURL>& url_chain,
    const scoped_refptr<const net::HttpResponseHeaders>& headers) {
  // Do not remove. This is a hook used by integration tests that test
  // client-server interaction.
  LOCAL_HISTOGRAM_BOOLEAN(
      "OptimizationGuide.PredictionModelDownloadClient.DownloadStarted", true);
}

void PredictionModelDownloadClient::OnDownloadFailed(
    const std::string& guid,
    const download::CompletionInfo& completion_info,
    download::Client::FailureReason reason) {
  PredictionModelDownloadManager* download_manager =
      GetPredictionModelDownloadManager();
  if (download_manager)
    download_manager->OnDownloadFailed(
        ParseOptimizationTarget(completion_info.custom_data), guid);
}

void PredictionModelDownloadClient::OnDownloadSucceeded(
    const std::string& guid,
    const download::CompletionInfo& completion_info) {
  PredictionModelDownloadManager* download_manager =
      GetPredictionModelDownloadManager();
  if (download_manager)
    download_manager->OnDownloadSucceeded(
        ParseOptimizationTarget(completion_info.custom_data), guid,
        completion_info.path);
}

bool PredictionModelDownloadClient::CanServiceRemoveDownloadedFile(
    const std::string& guid,
    bool force_delete) {
  // Always return true. We immediately postprocess successful downloads and the
  // file downloaded by the Download Service should already be deleted and this
  // hypothetically should never be called with anything that matters.
  return true;
}

void PredictionModelDownloadClient::GetUploadData(
    const std::string& guid,
    download::GetUploadDataCallback callback) {
  base::SequencedTaskRunnerHandle::Get()->PostTask(
      FROM_HERE, base::BindOnce(std::move(callback), nullptr));
}

}  // namespace optimization_guide
