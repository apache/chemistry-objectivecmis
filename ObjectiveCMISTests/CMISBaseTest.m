/*
  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
 */
 
#import "CMISBaseTest.h"
#import "CMISFolder.h"
#import "CMISSession.h"
#import "CMISConstants.h"
#import "CMISLog.h"

@implementation CMISBaseTest

- (void) runTest:(CMISTestBlock)testBlock
{
    [self runTest:testBlock withExtraSessionParameters:nil];
}

- (void) runTest:(CMISTestBlock)testBlock withExtraSessionParameters:(NSDictionary *)extraSessionParameters
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    XCTAssertNotNil(bundle, @"Bundle is nil!");

    NSString *envsPListPath = [bundle pathForResource:@"env-cfg" ofType:@"plist"];
    XCTAssertNotNil(envsPListPath, @"envsPListPath is nil!");

    NSDictionary *environmentsDict = [[NSDictionary alloc] initWithContentsOfFile:envsPListPath];
    XCTAssertNotNil(environmentsDict, @"environmentsDict is nil!");

    NSArray *environmentArray = [environmentsDict objectForKey:@"environments"];
    XCTAssertNotNil(environmentArray, @"environmentArray is nil!");

    for (NSDictionary *envDict in environmentArray) {
        NSString *url = [envDict valueForKey:@"url"];
        NSString *repositoryId = [envDict valueForKey:@"repositoryId"];
        NSString *username = [envDict valueForKey:@"username"];
        NSString *password = [envDict valueForKey:@"password"];

        self.testCompleted = NO;
        [self setupCmisSession:url repositoryId:repositoryId username:username password:password extraSessionParameters:extraSessionParameters completionBlock:^{
            self.testCompleted = NO;
            
            CMISLogDebug(@">------------------- Running test against %@ -------------------<", url);
            
            testBlock();
        }];
        [self waitForCompletion:90];
    }
}

- (void)setupCmisSession:(NSString *)url repositoryId:(NSString *)repositoryId username:(NSString *)username
                  password:(NSString *)password extraSessionParameters:(NSDictionary *)extraSessionParameters
         completionBlock:(void (^)(void))completionBlock
{
    self.parameters = [[CMISSessionParameters alloc] initWithBindingType:CMISBindingTypeAtomPub];
    self.parameters.username = username;
    self.parameters.password = password;
    self.parameters.atomPubUrl = [NSURL URLWithString:url];
    self.parameters.repositoryId = repositoryId;

    // Extra cmis params could be provided as method parameter
    if (extraSessionParameters != nil) {
        for (id extraSessionParamKey in extraSessionParameters) {
            [self.parameters setObject:[extraSessionParameters objectForKey:extraSessionParamKey] forKey:extraSessionParamKey];
        }
    }

    // Or, extra cmis parameters could be provided by overriding a base method
    NSDictionary *customParameters = [self customCmisParameters];
    if (customParameters) {
        for (id customParamKey in customParameters) {
            [self.parameters setObject:[customParameters objectForKey:customParamKey] forKey:customParamKey];
        }
    }
    [CMISSession connectWithSessionParameters:self.parameters completionBlock:^(CMISSession *session, NSError *error){
        if (nil == session) {
            XCTFail(@"Failed to create session: %@", error.localizedDescription);
            self.testCompleted = YES;
        } else {
            self.session = session;
            XCTAssertTrue(self.session.isAuthenticated, @"Session should be authenticated");
            [self.session retrieveRootFolderWithCompletionBlock:^(CMISFolder *rootFolder, NSError *error) {
                self.rootFolder = rootFolder;
                XCTAssertNil(error, @"Error while retrieving root folder: %@", [error description]);
                XCTAssertNotNil(self.rootFolder, @"rootFolder object should not be nil");
                
                completionBlock();
            }];
        }
    }];

}

- (NSDictionary *)customCmisParameters
{
    // Meant to be overridden.
    return nil;
}

#pragma mark Helper Methods

- (void)retrieveVersionedTestDocumentWithCompletionBlock:(void (^)(CMISDocument *document))completionBlock
{
    [self.session retrieveObjectByPath:@"/ios-test/versioned-quote.txt" completionBlock:^(CMISObject *object, NSError *error) {
        CMISDocument *document = (CMISDocument *)object;
        XCTAssertNotNil(document, @"Did not find test document for versioning test");
        XCTAssertTrue(document.isLatestVersion, @"Should have 'true' for the property 'isLatestVersion");
        XCTAssertFalse(document.isLatestMajorVersion, @"Should have 'false' for the property 'isLatestMajorVersion"); // the latest version is a minor one
        XCTAssertFalse(document.isMajorVersion, @"Should have 'false' for the property 'isMajorVersion");
        
        completionBlock(document);
    }];
}

- (void)uploadTestFileWithCompletionBlock:(void (^)(CMISDocument *document))completionBlock
{
    // Set properties on test file
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file.txt" ofType:nil];
    NSString *documentName = [NSString stringWithFormat:@"test_file_%@.txt", [self stringFromCurrentDate]];
    NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
    [documentProperties setObject:documentName forKey:kCMISPropertyName];
    [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];

    // Upload test file
    __block long long previousUploadedBytes = -1;
    __block NSString *objectId = nil;
    [self.rootFolder createDocumentFromFilePath:filePath
                                       mimeType:@"text/plain"
                                     properties:documentProperties
                                completionBlock: ^ (NSString *newObjectId, NSError *error){
                if (newObjectId) {
                    objectId = newObjectId;
                    
                    [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                        CMISDocument *document = (CMISDocument *)object;
                        XCTAssertNil(error, @"Got error while creating document: %@", [error description]);
                        XCTAssertNotNil(objectId, @"Object id received should be non-nil");
                        XCTAssertNotNil(document, @"Retrieved document should not be nil");
                        completionBlock(document);
                    }];
                } else {
                    XCTAssertNotNil(error, @"Object id should not be nil");
                    XCTAssertNil(error, @"Got error while uploading document: %@", [error description]);
                }
            }
            progressBlock: ^ (unsigned long long uploadedBytes, unsigned long long totalBytes, BOOL *stop)
            {
                XCTAssertTrue((long long)uploadedBytes > previousUploadedBytes, @"no progress");
                previousUploadedBytes = uploadedBytes;
            }];

}

- (void)waitForCompletion:(NSTimeInterval)timeoutSecs
{
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeoutSecs];
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
    } while (!self.testCompleted && [timeoutDate timeIntervalSinceNow] > 0);

    XCTAssertTrue(self.testCompleted, @"Test did not complete within %d seconds", (int)timeoutSecs);

    self.testCompleted = NO;
}

- (void)deleteDocumentAndVerify:(CMISDocument *)document completionBlock:(void (^)(void))completionBlock
{
    [document deleteAllVersionsWithCompletionBlock:^(BOOL documentDeleted, NSError *error) {
        XCTAssertNil(error, @"Error while deleting created document: %@", [error description]);
        XCTAssertTrue(documentDeleted, @"Document was not deleted");
        completionBlock();
    }];
}

- (NSDateFormatter *)testDateFormatter
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat: @"yyyy-MM-dd'T'HH-mm-ss-Z'"];
    return formatter;
}

- (NSString *)stringFromCurrentDate
{
    return [[self testDateFormatter] stringFromDate:[NSDate date]];
}


@end