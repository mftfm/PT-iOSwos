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
    NSError* folderError = nil;
    if (![fileManager createDirectoryAtURL:documents
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&folderError]) {
        if (error) *error = folderError;
        NSLog(@"[PT] Cannot prepare Files/Documents: %@", folderError.localizedDescription);
        return nil;
    }

    NSURL* profileFolder = [documents URLByAppendingPathComponent:@"P.T." isDirectory:YES];
    if (![fileManager createDirectoryAtURL:profileFolder
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&folderError]) {
        if (error) *error = folderError;
        NSLog(@"[PT] Cannot create Files/Documents/P.T.: %@", folderError.localizedDescription);
        return nil;
    }

    NSURL* gameFolder = [documents URLByAppendingPathComponent:@"Game" isDirectory:YES];
    if (![fileManager createDirectoryAtURL:gameFolder
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&folderError]) {
        if (error) *error = folderError;
        NSLog(@"[PT] Cannot create Files/Documents/Game: %@", folderError.localizedDescription);
        return nil;
    }

    NSURL* gameReadme = [gameFolder URLByAppendingPathComponent:@"README.txt" isDirectory:NO];
    if (![fileManager fileExistsAtPath:gameReadme.path]) {
        NSString* instructions =
            @"P.T. GAME DATA\n\n"
             "Copy these three files directly into this Game folder:\n\n"
             "chunk1.psarc\n"
             "texture.qar\n"
             "pathid_list_ps4.bin\n\n"
             "Close and reopen P.T. after copying the files.\n";
        NSError* readmeError = nil;
        if (![instructions writeToURL:gameReadme
                           atomically:YES
                             encoding:NSUTF8StringEncoding
                                error:&readmeError]) {
            NSLog(@"[PT] Could not write Game/README.txt: %@", readmeError.localizedDescription);
        }
    }

    NSURL* profileReadme = [profileFolder URLByAppendingPathComponent:@"README.txt" isDirectory:NO];
    if (![fileManager fileExistsAtPath:profileReadme.path]) {
        NSString* instructions = @"P.T. settings, logs and diagnostic files are stored in this folder.\n";
        NSError* readmeError = nil;
        if (![instructions writeToURL:profileReadme
                           atomically:YES
                             encoding:NSUTF8StringEncoding
                                error:&readmeError]) {
            NSLog(@"[PT] Could not write P.T./README.txt: %@", readmeError.localizedDescription);
        }
    }

    NSNumber* gameIsDirectory = nil;
    NSNumber* profileIsDirectory = nil;
    [gameFolder getResourceValue:&gameIsDirectory forKey:NSURLIsDirectoryKey error:&folderError];
    [profileFolder getResourceValue:&profileIsDirectory forKey:NSURLIsDirectoryKey error:&folderError];
    if (!gameIsDirectory.boolValue || !profileIsDirectory.boolValue) {
        if (error) *error = folderError ?: [NSError errorWithDomain:@"PTDocumentFolder" code:2
            userInfo:@{NSLocalizedDescriptionKey:@"The Files app folders were not created as directories."}];
        return nil;
    }

    NSLog(@"[PT] Files app folders ready: %@ and %@", gameFolder.path, profileFolder.path);
    return gameFolder;
}