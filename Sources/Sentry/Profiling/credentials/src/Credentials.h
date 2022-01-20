// Copyright (c) Specto Inc. All rights reserved.

#pragma once

namespace specto::credentials {

void init(const char *APIKey);

/**
 * @returns true if the global credentials proto was already initialized with an API key, false
 * otherwise.
 */
bool initialized();

/** @returns The API key provided by the SDK consumer upon init. */
const char *APIKey();

} // namespace specto::credentials
