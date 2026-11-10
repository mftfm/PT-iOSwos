#pragma once

#import <Foundation/Foundation.h>

// Ensures the app's shareable Documents/Game folder exists and contains
// first-launch instructions. Existing user README edits are never overwritten.
// Returns nil only if the Documents directory or Game folder cannot be prepared.
NSURL* PTPrepareGameFolder(NSURL* documents, NSError** error);
