#import "document_folder.h"

NSURL* PTPrepareGameFolder(NSURL* documents, NSError** error) {
    if (error) *error = nil;
    if (!documents || !documents.isFileURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"PTDocumentFolder"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"The app's Files/Documents directory is unavailable."}];
        }
        return nil;
    }

    NSFileManager* fileManager = NSFileManager.defaultManager;
    NSURL* gameFolder = [documents URLByAppendingPathComponent:@"Game" isDirectory:YES];
    NSError* folderError = nil;
    if (![fileManager createDirectoryAtURL:gameFolder
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&folderError]) {
        if (error) *error = folderError;
        NSLog(@"[PT] Could not create Documents/Game: %@", folderError.localizedDescription);
        return nil;
    }

    NSURL* readme = [gameFolder URLByAppendingPathComponent:@"README.txt" isDirectory:NO];
    if (![fileManager fileExistsAtPath:readme.path]) {
        NSString* instructions =
            @"P.T. GAME DATA\n\n"
             "Copy these three files directly into this Game folder:\n\n"
             "chunk1.psarc\n"
             "texture.qar\n"
             "pathid_list_ps4.bin\n\n"
             "Close and reopen P.T. after copying the files.\n";
        NSError* readmeError = nil;
        if (![instructions writeToURL:readme
                           atomically:YES
                             encoding:NSUTF8StringEncoding
                                error:&readmeError]) {
            // The folder itself is useful even when creating the optional
            // instructions file fails (for example, because storage is full).
            NSLog(@"[PT] Could not write Documents/Game/README.txt: %@", readmeError.localizedDescription);
        }
    }
    return gameFolder;
}
