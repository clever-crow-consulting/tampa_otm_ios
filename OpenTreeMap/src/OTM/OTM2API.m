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

#import "OTM2API.h"
#import "OTMAPI.h"
#import "OTMEnvironment.h"

@interface OTM2API()
@end

@implementation OTM2API

-(void)loadInstanceInfo:(NSString*)instance
           withCallback:(AZJSONCallback)callback {

  self.species = nil; // Clear species cache

  [self loadInstanceInfo:instance
                 forUser:[[SharedAppDelegate loginManager] loggedInUser]
            withCallback:callback];
}

-(void)loadInstanceInfo:(NSString*)instance
                forUser:(AZUser*)user
           withCallback:(AZJSONCallback)callback {

  [self.noPrefixRequest get:@"instance/:instance"
               withUser:user
                 params:@{@"instance" : instance}
               callback:[OTMAPI liftResponse:
                                  [OTMAPI jsonCallback:callback]]];

}

-(NSString *)tileUrlTemplateForInstanceId:(NSString *)iid
                                   geoRev:(NSString *)rev
                                    layer:(NSString *)layer {
    return [NSString stringWithFormat:
                         @"/tile/%@/database/otm/table/%@/{z}/{x}/{y}.png?instance_id=%@&scale={scale}", rev, layer, iid];
}

-(void)logUserIn:(OTMUser*)user callback:(AZUserCallback)callback {
    
    NSLog(@"Entering logUserIn...");
    
    [self.noPrefixRequest get:@"user"
                 withUser:user
                   params:nil
                 callback:[OTMAPI liftResponse:[OTMAPI jsonCallback:^(id json, NSError* error) {
            if (error) {
              
              [user setLoggedIn:NO];
                
              if (error.code == 401) {
                  
                NSLog(@"Value of error.code is %ld", (long)error.code);
                  
                callback(nil, nil, kOTMAPILoginResponseInvalidUsernameOrPassword);
                  
              } else {
                  
                NSLog(@"Value of error.code is %ld", (long)error.code);
                  
                callback(nil, nil, kOTMAPILoginResponseError);
              }
            } else {
              
                NSLog(@"No errors. Setting user details...");
                
              user.email = [json objectForKey:@"email"];
              user.firstName = [json objectForKey:@"first_name"];
              user.lastName = [json objectForKey:@"last_name"];
              user.userId = [[json valueForKey:@"id"] intValue];
              user.reputation = [[json valueForKey:@"reputation"] intValue];

              [user setLoggedIn:YES];
                NSLog(@"Debugging loadInstanceInfo forUser:user with Callback");
                [self loadInstanceInfo:[[OTMEnvironment sharedEnvironment] instance]
                             forUser:user
                        withCallback:^(id json, NSError *error) {
                  if (!error) {
                    [[OTMEnvironment sharedEnvironment] updateEnvironmentWithDictionary:json];
                  }
                  callback(user, json, kOTMAPILoginResponseOK);
                }];
            }
                }]]];

}

@end
