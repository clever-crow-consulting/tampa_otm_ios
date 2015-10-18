// This file is part of the OpenTreeMap code.
//
// OpenTreeMap is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// OpenTreeMap is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with OpenTreeMap.  If not, see <http://www.gnu.org/licenses/>.

#import "OTMAPI.h"
#import "ASIHTTPRequest.h"
#import "OTMReverseGeocodeOperation.h"
#import "OTMEnvironment.h"

@interface OTMAPI()

@end

@implementation OTMAPI

+(ASIRequestCallback)liftResponse:(AZGenericCallback)callback {
    if (callback == nil) { return [^(id obj, id error) {} copy]; }
    NSLog(@"req");
    return [^(ASIHTTPRequest* req) {
        NSLog(@"debugging");
        if (req.responseStatusCode >= 200 && req.responseStatusCode <= 299) {
            callback([req responseData], nil);
        } else {
            NSString *responseBodyAsString = [[NSString alloc] initWithData:[req responseData] encoding:NSUTF8StringEncoding];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                req.url, @"url",
                req.requestMethod, @"method",
                responseBodyAsString, @"body",
                [NSNumber numberWithInt:req.responseStatusCode], @"statusCode",
                nil];
            NSError* error = [[NSError alloc] initWithDomain:@"otm"
                                                        code:req.responseStatusCode
                                                    userInfo:userInfo];
            callback(nil, error);
        }
    } copy];
}

+(AZGenericCallback)jsonCallback:(AZGenericCallback)callback {
    NSLog(@"debugging...");
    if (callback == nil) { return [^(id obj, id error) {} copy]; }
    return [^(NSData* data, NSError* error) {
            if (error) {
                callback(nil, error);
            } else {
                NSError* error = nil;

                id json = [NSJSONSerialization JSONObjectWithData:data
                                                          options:0
                                                            error:&error];
                callback(json, error);
            }
    } copy];
}

-(id)init {
    if ((self = [super init])) {
    }
    return self;
}

-(void)getSpeciesListForUser:(OTMUser *)user withCallback:(AZJSONCallback)callback {
    if (species != nil) {
        if (callback) {
            callback(species, nil);
        }
    } else {
        [self.request get:@"species"
                 withUser:user
                   params:nil
                 callback:[OTMAPI liftResponse:
                           [OTMAPI jsonCallback:^(id json, NSError *err) {
                     if (err != nil) {
                         if (callback) { callback(nil, err); }
                     } else {
                         NSMutableDictionary *s = [NSMutableDictionary dictionary];

                         [json enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                             [s setObject:obj
                                   forKey:[obj objectForKey:@"common_name"]];
                         }];
                         species = s;
                         if (callback) { callback(species, nil); }
                     }
                 }]]];

    }
}

-(void)resetSpeciesList{
    species = nil;
}

-(void)getAllPublicInstancesWithCallback:(AZJSONCallback)callback {
    if (instances != nil) {
        if (callback) {
            callback(instances, nil);
        }
    } else {
        [self.noPrefixRequest get:@"instances"
                 withUser:nil
                   params:nil
                 callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:^(id json, NSError *err) {
                     if (err != nil) {
                         if (callback) { callback(nil, err); }
                     } else {
                         NSMutableDictionary *inst = [NSMutableDictionary dictionary];

                         [json enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                             [inst setObject:[obj objectForKey:@"url"]
                                      forKey:[obj objectForKey:@"name"]];
                         }];
                         instances = inst;

                         if (callback) { callback(instances, nil); }
                     }
                }]]];
    }
}

-(void)getPlotsNearLatitude:(double)lat longitude:(double)lon user:(OTMUser *)user callback:(AZJSONCallback)callback {
    [self getPlotsNearLatitude:lat longitude:lon user:user maxResults:1 callback:callback];
}

-(void)getPlotsNearLatitude:(double)lat longitude:(double)lon user:(OTMUser *)user filters:(OTMFilters *)filters callback:(AZJSONCallback)callback {
    [self getPlotsNearLatitude:lat longitude:lon user:user maxResults:1 filters:filters callback:callback];
}

-(void)getPlotsNearLatitude:(double)lat longitude:(double)lon user:(OTMUser *)user maxResults:(NSUInteger)max callback:(AZJSONCallback)callback {
    [self getPlotsNearLatitude:lat longitude:lon user:user maxResults:max filters:nil callback:callback];
}

-(void)getPlotsNearLatitude:(double)lat longitude:(double)lon user:(OTMUser *)user maxResults:(NSUInteger)max filters:(OTMFilters *)filters callback:(AZJSONCallback)callback {
    [self getPlotsNearLatitude:lat longitude:lon user:user maxResults:max filters:filters distance:0 callback:callback];
}

-(void)getPlotsNearLatitude:(double)lat longitude:(double)lon user:(OTMUser *)user maxResults:(NSUInteger)max filters:(OTMFilters *)filters distance:(double)distance callback:(AZJSONCallback)callback {

    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [NSString stringWithFormat:@"%f", lat], @"lat",
                                   [NSString stringWithFormat:@"%f", lon], @"lon",
                                   [NSNumber numberWithInt:max], @"max_plots", nil];

    if (filters != nil) {
        NSString *filter = [filters filtersAsUrlParameter];

        if (filter) {
            filter = [OTMAPI urlEncode:filter];
            [params addEntriesFromDictionary:@{@"q": filter}];
        }
    }

    if (distance > 0) {
        [params setObject:[NSString stringWithFormat:@"%f", distance]
                   forKey:@"distance"];
    }

    [self.request get:@"locations/:lat,:lon/plots"
             withUser:user
               params:params
             callback:[OTMAPI liftResponse:
                       [OTMAPI jsonCallback:callback]]];
}

-(void)getInstancesNearLatitude:(double)lat longitude:(double)lon user:(OTMUser *)user maxResults:(NSUInteger)max distance:(double)distance callback:(AZJSONCallback)callback {

    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [NSString stringWithFormat:@"%f", lat], @"lat",
                                   [NSString stringWithFormat:@"%f", lon], @"lon",
                                   [NSNumber numberWithInt:max], @"max", nil];

    NSString *url = @"locations/:lat,:lon/instances";

    if (distance > 0) {
        [params setObject:[NSString stringWithFormat:@"%f", distance]
                   forKey:@"distance"];
    }

    if (user) {
        [_noPrefixRequest get:url
                     withUser:user
                       params:params
                     callback:[OTMAPI liftResponse:
                               [OTMAPI jsonCallback:callback]]];
    } else {
        [_noPrefixRequest get:url
                       params:params
                     callback:[OTMAPI liftResponse:
                               [OTMAPI jsonCallback:callback]]];

    }
}

-(void)getProfileForUser:(OTMUser *)user callback:(AZJSONCallback)callback {
    [_noPrefixRequest get:@"user"
                 withUser:user
                   params:nil
                 callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)resetPasswordForEmail:(NSString*)email callback:(AZJSONCallback)callback {
    // I was getting invalid signature errors unless I URL encoded the email address
    [_noPrefixRequest post:@"send-password-reset-email"
                    params:[NSDictionary dictionaryWithObject:[OTMAPI urlEncode:email] forKey:@"email"]
                      data:nil
                  callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];

}

-(NSData *)encodeUser:(OTMUser *)user {
    NSMutableDictionary *userDict = [NSMutableDictionary dictionary];
    [userDict setObject:user.username forKey:@"username"];
    [userDict setObject:user.firstName forKey:@"first_name"];
    [userDict setObject:user.lastName forKey:@"last_name"];
    [userDict setObject:user.email forKey:@"email"];
    [userDict setObject:user.password forKey:@"password"];

    return [OTMAPI jsonEncode:userDict];
}

+(NSString *)urlEncode:(NSString *)string {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                 (__bridge CFStringRef) string,
                                                                                 NULL,
                                                                                 CFSTR("!*'();:@&=+$,/?%#[]\" "),
                                                                                 kCFStringEncodingUTF8));
}

+(NSData *)jsonEncode:(id)obj {
    NSError *error = NULL;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:obj options:0 error:&error];
    if (error != NULL) {
        NSLog(@"[ERROR] Could not encode \"%@\" as json (error: %@)",obj,error);
    }

    return jsonData;
}

-(void)setProfilePhoto:(OTMUser *)user callback:(AZJSONCallback)callback {
     [_noPrefixRequest post:@"user/:user_id/photo"
                   withUser:user
                     params:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:user.userId]
                                                        forKey:@"user_id"]
                       // JPEG compression level is 0.0 to 1.0 with 1.0 being no compression, so 0.2 is 80% compression.
                       data:UIImageJPEGRepresentation(user.photo, 0.2)
                contentType:@"image/jpeg"
                   callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)setPhoto:(UIImage *)image onPlotWithID:(NSUInteger)pId withUser:(OTMUser *)user callback:(AZJSONCallback)cb {
    [_request post:@"plots/:plot_id/tree/photo"
         withUser:user
           params:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:pId]
                                              forKey:@"plot_id"]
             data:UIImageJPEGRepresentation(image, 0.2) // JPEG compression level is 0.0 to 1.0 with 1.0 being no compression, so 0.2 is 80% compression.
      contentType:@"image/jpeg"
         callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:cb]]];
}

-(void)createUser:(OTMUser *)user callback:(AZUserCallback)callback {
    [_noPrefixRequest post:@"user"
                    params:nil
                      data:[self encodeUser:user]
                  callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:^(NSDictionary *json, NSError *error)
    {
        if (callback != nil) {
            if (error != nil) {
                NSDictionary *info = [error userInfo];
                NSNumber *statusCode = [info objectForKey:@"statusCode"];
                NSString *message = [info objectForKey:@"body"];
                if (statusCode && [statusCode intValue] == 409) {
                    if ([message isEqualToString:@"Email is already in use"]) {
                        callback(user, nil, kOTMAPILoginDuplicateEmailAddress);
                    } else {
                        callback(user, nil, kOTMAPILoginDuplicateUsername);
                    }
                } else {
                    callback(user, nil, kOTMAPILoginResponseError);
                }
            } else {
                if ([[json objectForKey:@"status"] isEqualToString:@"success"]) {
                    user.userId = [[json valueForKey:@"id"] intValue];
                    callback(user, nil, kOTMAPILoginResponseOK);
                } else {
                    callback(user, nil, kOTMAPILoginResponseError);
                }
            }
        }
    }]]];
}

-(void)changePasswordForUser:(OTMUser *)user to:(NSString *)newPass callback:(AZUserCallback)callback {
    [_noPrefixRequest put:@"user/:user_id"
                 withUser:user
                   params:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:user.userId]
                                             forKey:@"user_id"]
                     data:[OTMAPI jsonEncode:[NSDictionary dictionaryWithObject:newPass forKey:@"password"]]
                 callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:^(NSDictionary *json, NSError *error)
        {
            if (callback != nil) {
                if (error != nil) {
                    callback(user, nil, kOTMAPILoginResponseError);
                } else {
                    callback(user, nil, kOTMAPILoginResponseOK);
                }
            }
        }]]];

}

-(void)getRecentActionsForUser:(OTMUser *)user callback:(AZJSONCallback)callback {
    [self getRecentActionsForUser:user offset:0 length:5 callback:callback];
}

-(void)getRecentActionsForUser:(OTMUser *)user offset:(NSUInteger)offset callback:(AZJSONCallback)callback {
    [self getRecentActionsForUser:user offset:offset length:5 callback:callback];
}

-(void)getRecentActionsForUser:(OTMUser *)user offset:(NSUInteger)offset length:(NSUInteger)length callback:(AZJSONCallback)callback {
    [_noPrefixRequest get:@"user/:user_id/edits"
                 withUser:user
                   params:[NSDictionary
                              dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:user.userId],
                              @"user_id",
                                   [NSNumber numberWithInt:offset],
                              @"offset",
                                   [NSNumber numberWithInt:length],
                              @"length", nil]
                 callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)geocodeAddress:(NSString *)address callback:(AZJSONCallback)callback
{
    if (callback == nil) { return; }
    if ([[OTMEnvironment sharedEnvironment] useOtmGeocoder]) {
        [self geocodeWithOtmGeocoder:address callback:callback];
    } else {
        [self geocodeWithCLGeocoder:address callback:callback];
    }
}

-(void)geocodeWithOtmGeocoder:(NSString *)address callback:(AZJSONCallback)callback
{
     NSString *urlEncodedSearchText = [address stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
     [_request get:@"addresses/:address"
     params:[NSDictionary dictionaryWithObject:urlEncodedSearchText forKey:@"address"]
     callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)geocodeWithCLGeocoder:(NSString *)address callback:(AZJSONCallback)callback
{
    if (geocodeRegion == nil) {
        CLLocationCoordinate2D center = [[OTMEnvironment sharedEnvironment] mapViewInitialCoordinateRegion].center;
        double radius = [[OTMEnvironment sharedEnvironment] searchRegionRadiusInMeters];
        geocodeRegion = [[CLRegion alloc] initCircularRegionWithCenter:center radius:radius identifier:@"geocoderRegion"];
    }

    if (geocoder == nil) {
        geocoder = [[CLGeocoder alloc] init];
    }

    [geocoder geocodeAddressString:address inRegion:geocodeRegion completionHandler:^(NSArray *placemarks, NSError *error) {
        if (error) { callback(nil, error); }
        NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:[placemarks count]];
        for (CLPlacemark *placemark in placemarks) {
            CLLocationCoordinate2D coordinate = [[placemark location] coordinate];
            if ([geocodeRegion containsCoordinate:coordinate]) {
                [results addObject:[self createDictionaryFromPlacemark:placemark]];
            } else {
                NSLog(@"Excluding CLGeocoder result lat:%f lon:%f outside the geocoding region defined in the environment", coordinate.latitude, coordinate.longitude);
            }
        }
        callback(results, nil);
    }];
}

-(NSDictionary *)createDictionaryFromPlacemark:(CLPlacemark *)placemark
{
    CLLocationCoordinate2D coordinate = [[placemark location] coordinate];
    // This dictionary format is matches the JSON format returned by the server-side
    // OTM geocoder API, so the two gecoders can be used interchangably.
    return [[NSDictionary alloc] initWithObjectsAndKeys:
            @"", @"match_addr",
            [NSNumber numberWithDouble:coordinate.longitude], @"x",
            [NSNumber numberWithDouble:coordinate.latitude], @"y",
            [NSNumber numberWithInt:100], @"score", // CLGeocoder responses are not ranked with a score
            @"CLGeocoder", @"locator",
            @"iOS", @"geoservice",
            [NSNumber numberWithInt:4326], @"wkid",
            nil];
}

-(void)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate callback:(AZGenericCallback)callback
{
    if (!geocodeQueue) {
        geocodeQueue = [[NSOperationQueue alloc] init];
        [geocodeQueue setMaxConcurrentOperationCount:1];
    }

    OTMReverseGeocodeOperation *operation = [[OTMReverseGeocodeOperation alloc] initWithCoordinate:coordinate callback:callback];

    [geocodeQueue addOperation:operation];
}

-(void)addPlotWithOptionalTree:(NSDictionary *)details user:(OTMUser *)user callback:(AZJSONCallback)callback
{
    [_request post:@"plots"
         withUser:user
           params:nil
             data:[OTMAPI jsonEncode:details]
      contentType:@"image/png"
         callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)updatePlotAndTree:(NSDictionary *)details user:(OTMUser *)user callback:(AZJSONCallback)callback
{
    NSString *pk = details[@"plot"][@"id"];
    if (pk == nil) {
        if (callback) {
            callback(nil, [NSError errorWithDomain:@"No id specified in details dictionary" code:0 userInfo:details]);
        }
    }
    [_request put:@"plots/:id"
        withUser:user
          params:[NSDictionary dictionaryWithObject:pk forKey:@"id"]
            data:[OTMAPI jsonEncode:details]
        callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)approvePendingEdit:(NSInteger)pendingEditId user:(OTMUser *)user callback:(AZJSONCallback)callback
{
    [_request post:@"pending-edits/:id/approve/"
        withUser:user
          params:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:pendingEditId] forKey:@"id"]
            data:nil
      contentType:@"application/json"
        callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)rejectPendingEdit:(NSInteger)pendingEditId user:(OTMUser *)user callback:(AZJSONCallback)callback
{
    [_request post:@"pending-edits/:id/reject/"
         withUser:user
           params:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:pendingEditId] forKey:@"id"]
             data:nil
      contentType:@"application/json"
         callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)deleteTreeFromPlot:(NSInteger)plotId user:(OTMUser *)user callback:(AZJSONCallback)callback
{
    [_request delete:@"plots/:id/tree"
         withUser:user
           params:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:plotId] forKey:@"id"]
         callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)deletePlot:(NSInteger)plotId user:(OTMUser *)user callback:(AZJSONCallback)callback
{
    [_request delete:@"plots/:id"
           withUser:user
             params:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:plotId] forKey:@"id"]
           callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)getPlotInfo:(NSInteger)plotId user:(OTMUser *)user callback:(AZJSONCallback)callback {
  [_request get:@"plots/:id"
      withUser:user
        params:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:plotId] forKey:@"id"]
      callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:callback]]];
}

-(void)getTreeImage:(NSString*)url callback:(AZImageCallback)callback {
    [_noPrefixRequest getRaw:url
                  params:nil
                    mime:@"image/jpeg"
                callback:[OTMAPI liftResponse:^(id data, NSError* error) {
                if (callback) {
                    if (error != nil) {
                        callback(nil, error);
                    } else {
                        callback([UIImage imageWithData:data], nil);
                    }
                }
            }]];
}

@end
