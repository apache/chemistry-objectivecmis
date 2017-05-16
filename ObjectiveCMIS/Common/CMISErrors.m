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

#import "CMISErrors.h"
#import "CMISDictionaryUtil.h"

NSString * const kCMISErrorDomainName = @"org.apache.chemistry.objectivecmis";
//to be used in the userInfo dictionary as Localized error description

/**
 Note, the string definitions below should not be used by themselves. Rather, they should be used to 
 obtain the localized string. Therefore, the proper use in the code would be e.g.
 LocalizedString(kCMISNoReturnErrorDescription,kCMISNoReturnErrorDescription)
 (the second parameter in LocalizedString is a Comment and may be set to nil)
 */
//Basic Errors

NSString * const kCMISErrorDescriptionUnknown = @"Unknown Error";
NSString * const kCMISErrorDescriptionConnection = @"Connection Error";
NSString * const kCMISErrorDescriptionProxyAuthentication = @"Proxy Authentication Error";
NSString * const kCMISErrorDescriptionUnauthorized = @"Unauthorized Access";
NSString * const kCMISErrorDescriptionNoRootFolderFound =  @"Root Folder Not Found";
NSString * const kCMISErrorDescriptionRepositoryNotFound =  @"Repository Not Found";
NSString * const kCMISErrorDescriptionCancelled = @"Operation Cancelled";
NSString * const kCMISErrorDescriptionParsingFailed = @"Parsing Failed";
NSString * const kCMISErrorDescriptionNoNetworkConnection = @"No Network Connection";

//General errors as defined in 2.2.1.4.1 of spec
NSString * const kCMISErrorDescriptionInvalidArgument = @"Invalid Argument Error";
NSString * const kCMISErrorDescriptionObjectNotFound = @"Object Not Found Error";
NSString * const kCMISErrorDescriptionNotSupported = @"Not Supported Error";
NSString * const kCMISErrorDescriptionPermissionDenied = @"Permission Denied Error";
NSString * const kCMISErrorDescriptionRuntime = @"Runtime Error";

//Specific errors as defined in 2.2.1.4.2
NSString * const kCMISErrorDescriptionConstraint = @"Constraint Error";
NSString * const kCMISErrorDescriptionContentAlreadyExists = @"Content Already Exists Error";
NSString * const kCMISErrorDescriptionFilterNotValid = @"Filter Not Valid Error";
NSString * const kCMISErrorDescriptionNameConstraintViolation = @"Name Constraint Violation Error";
NSString * const kCMISErrorDescriptionStorage = @"Storage Error";
NSString * const kCMISErrorDescriptionStreamNotSupported = @"Stream Not Supported Error";
NSString * const kCMISErrorDescriptionUpdateConflict = @"Update Conflict Error";
NSString * const kCMISErrorDescriptionVersioning = @"Versioning Error";

//OAuth specific - to be used in the userInfo dictionary when OAuth token request fails
NSString * const kCMISErrorOAuthExceptionErrorKey = @"CMISErrorOAuthExceptionErrorKey";
NSString * const kCMISErrorOAuthExceptionDescriptionKey = @"CMISErrorOAuthExceptionDescriptionKey";
NSString * const kCMISErrorOAuthExceptionUriKey = @"CMISErrorOAuthExceptionUriKey";

//OAuth specific error codes as defined in RFC 6749 5.2
NSString * const kCMISErrorOAuthCodeInvalidRequest = @"invalid_request";
NSString * const kCMISErrorOAuthCodeInvalidClient = @"invalid_client";
NSString * const kCMISErrorOAuthCodeInvalidGrant = @"invalid_grant"; // ask the user to authenticate again
NSString * const kCMISErrorOAuthCodeUnauthorizedClient = @"unauthorized_client";
NSString * const kCMISErrorOAuthCodeUnsupportedGrantType = @"unsupported_grant_type";
NSString * const kCMISErrorOAuthCodeInvalidScope = @"invalid_scope";

//Bearer OAuth specific error codes as defined in RFC 6750 6.2
NSString * const kCMISErrorBearerOAuthCodeInvalidRequest = @"invalid_request";
NSString * const kCMISErrorBearerOAuthCodeInvalidToken = @"invalid_token"; // ask the user to authenticate again
NSString * const kCMISErrorBearerOAuthCodeInsufficientScope = @"insufficient_scope";



@interface CMISErrors ()
+ (NSString *)localizedDescriptionForCode:(CMISErrorCodes)code;
@end

@implementation CMISErrors

+ (NSError *)cmisError:(NSError *)error cmisErrorCode:(CMISErrorCodes)code
{
    if (error == nil) {//shouldn't really get there
        return nil;
    }
    
    if ([error.domain isEqualToString:kCMISErrorDomainName]) {
        return error;
    }
    
    NSDictionary *userInfo = [CMISDictionaryUtil userInfoDictionaryForErrorWithDescription:[CMISErrors localizedDescriptionForCode:code]
                                                                                    reason:nil
                                                                           underlyingError:error];
    return [NSError errorWithDomain:kCMISErrorDomainName code:code userInfo:userInfo];
}

+ (NSError *)createCMISErrorWithCode:(CMISErrorCodes)code detailedDescription:(NSString *)detailedDescription
{
    return [CMISErrors createCMISErrorWithCode:code detailedDescription:detailedDescription additionalUserInfo:nil];
}

+ (NSError *)createCMISErrorWithCode:(CMISErrorCodes)code detailedDescription:(NSString *)detailedDescription additionalUserInfo:(NSDictionary *)additionalUserInfo
{
    NSDictionary *userInfo = [CMISDictionaryUtil userInfoDictionaryForErrorWithDescription:[CMISErrors localizedDescriptionForCode:code]
                                                                                    reason:detailedDescription
                                                                           underlyingError:nil];
    if (additionalUserInfo) {
        NSMutableDictionary *mutableUserInfo = [userInfo mutableCopy];
        [mutableUserInfo addEntriesFromDictionary:additionalUserInfo];
        userInfo = [mutableUserInfo copy];
    }
    
    return [NSError errorWithDomain:kCMISErrorDomainName code:code userInfo:userInfo];
}

+ (NSString *)localizedDescriptionForCode:(CMISErrorCodes)code
{
    switch (code) {
        case kCMISErrorCodeUnknown:
            return kCMISErrorDescriptionUnknown;
        case kCMISErrorCodeConnection:
            return kCMISErrorDescriptionConnection;
        case kCMISErrorCodeProxyAuthentication:
            return kCMISErrorDescriptionProxyAuthentication;
        case kCMISErrorCodeUnauthorized:
            return kCMISErrorDescriptionUnauthorized;
        case kCMISErrorCodeNoRootFolderFound:
            return kCMISErrorDescriptionNoRootFolderFound;
        case kCMISErrorCodeNoRepositoryFound:
            return kCMISErrorDescriptionRepositoryNotFound;
        case kCMISErrorCodeCancelled:
            return kCMISErrorDescriptionCancelled;
        case kCMISErrorCodeParsingFailed:
            return kCMISErrorDescriptionParsingFailed;
        case kCMISErrorCodeNoNetworkConnection:
            return kCMISErrorDescriptionNoNetworkConnection;
        case kCMISErrorCodeInvalidArgument:
            return kCMISErrorDescriptionInvalidArgument;
        case kCMISErrorCodeObjectNotFound:
            return kCMISErrorDescriptionObjectNotFound;
        case kCMISErrorCodeNotSupported:
            return kCMISErrorDescriptionNotSupported;
        case kCMISErrorCodePermissionDenied:
            return kCMISErrorDescriptionPermissionDenied;
        case kCMISErrorCodeRuntime:
            return kCMISErrorDescriptionRuntime;
        case kCMISErrorCodeConstraint:
            return kCMISErrorDescriptionConstraint;
        case kCMISErrorCodeContentAlreadyExists:
            return kCMISErrorDescriptionContentAlreadyExists;
        case kCMISErrorCodeFilterNotValid:
            return kCMISErrorDescriptionFilterNotValid;
        case kCMISErrorCodeNameConstraintViolation:
            return kCMISErrorDescriptionNameConstraintViolation;
        case kCMISErrorCodeStorage:
            return kCMISErrorDescriptionStorage;
        case kCMISErrorCodeStreamNotSupported:
            return kCMISErrorDescriptionStreamNotSupported;
        case kCMISErrorCodeUpdateConflict:
            return kCMISErrorDescriptionUpdateConflict;
        case kCMISErrorCodeVersioning:
            return kCMISErrorDescriptionVersioning;
        default:
            return kCMISErrorDescriptionUnknown;
    }
    
}

@end
