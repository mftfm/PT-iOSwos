#pragma once

#import <Foundation/Foundation.h>

// Ensures shareable Documents/Game and Documents/P.T. folders exist.
// Adds first-launch instructions only when each README is missing.
// Returns nil when the Files/Documents folders cannot be prepared.
NSURL* PTPrepareGameFolder(NSURL* documents, NSError** error);
