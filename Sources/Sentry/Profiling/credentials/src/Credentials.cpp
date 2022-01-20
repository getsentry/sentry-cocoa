// Copyright (c) Specto Inc. All rights reserved.

#include "Credentials.h"

#include "Log.h"
#include "spectoproto/credentials/credentials_generated.pb.h"

namespace specto::credentials {

namespace {

std::shared_ptr<specto::proto::AppCredentials> gCredentials {nullptr};
std::mutex gCredentialsLock;

} // namespace

void init(const char *APIKey) {
    SPECTO_LOG_DEBUG("Setting up global credentials.");
    std::lock_guard<std::mutex> l(gCredentialsLock);
    if (gCredentials != nullptr) {
        SPECTO_LOG_WARN("+[Specto setUpWithAPIKey:] cannot be called more than once");
        return;
    }
    gCredentials = std::make_shared<proto::AppCredentials>();
    gCredentials->set_api_key(std::string(APIKey));
}

bool initialized() {
    std::lock_guard<std::mutex> l(gCredentialsLock);
    return gCredentials != nullptr;
}

const char *APIKey() {
    std::lock_guard<std::mutex> l(gCredentialsLock);
    if (gCredentials == nullptr) {
        SPECTO_LOG_WARN("Must call +[Specto initializeWithAppID:APIKey:] first");
        abort();
    }
    return gCredentials->api_key().c_str();
}

} // namespace specto::credentials
