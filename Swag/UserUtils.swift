//
//  User.swift
//  Swag
//
//  Created by Philip Massey on 8/18/15.
//  Copyright (c) 2015 Groovr. All rights reserved.
//

import Foundation

import FBSDKCoreKit
import Parse

// A set of utility functions surrounding Parse's currentUser
class UserUtils {
    
    //MARK: Facebook Communication
    
    class func loginWithAccessToken(token: FBSDKAccessToken, block: (Void) -> Void) {
        PFFacebookUtils.logInInBackgroundWithAccessToken(token, block: { (user, error) -> Void in
            if UserUtils.noFacebookError(error) {
                if let user = user {
                    NSLog("%@", user)
                    if self.needFacebookInfo(user) {
                        UserUtils.getFacebookInfo(user, block: block)
                    } else {
                        block()
                    }
                } else {
                    NSLog("Error parsing user from Login from Facebook Access Token")
                }
            }
        })
    }
    
    
    class func login(block: (Void) -> Void) {
        //let permission = ["user_about_me", "user_relationships", "user_birthday", "user_location"];
        PFFacebookUtils.logInInBackgroundWithReadPermissions(nil, block: { (user, error) -> Void in
            if UserUtils.noFacebookError(error) {
                if let user = user {
                    if UserUtils.needFacebookInfo(user) {
                        UserUtils.getFacebookInfo(user, block: block)
                    } else {
                        block()
                    }
                } else {
                    NSLog("User cancelled login")
                }
            }
        })
    }
    
    class func getFacebookFriends(block: (Void) -> Void) {
        UserUtils.makeFacebookGraphRequest("me?fields=friends", parameters: nil, block: { (result) -> Void in
            if let resultDictionary = result as? [String: AnyObject] {
                NSLog("%@", resultDictionary)
                if let friends = resultDictionary["friends"] as? [String: AnyObject] {
                    if let friendPairs = friends["data"] as? [[String: String]] {
                        
                        var friendIds = [String]()
                        for friendPair in friendPairs {
                            friendIds.append(friendPair["id"]!)
                        }
                        
                        NSLog("%@", friendIds)
                    }
                }
            }
        })
        
        /*
        [FBRequestConnection startForMyFriendsWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (!error) {
            // result will contain an array with your user's friends in the "data" key
            NSArray *friendObjects = [result objectForKey:@"data"];
            NSMutableArray *friendIds = [NSMutableArray arrayWithCapacity:friendObjects.count];
            // Create a list of friends' Facebook IDs
            for (NSDictionary *friendObject in friendObjects) {
            [friendIds addObject:[friendObject objectForKey:@"id"]];
            }
            
            // Construct a PFUser query that will find friends whose facebook ids
            // are contained in the current user's friend list.
            PFQuery *friendQuery = [PFUser query];
            [friendQuery whereKey:@"fbId" containedIn:friendIds];
            
            // findObjects will return a list of PFUsers that are friends
            // with the current user
            NSArray *friendUsers = [friendQuery findObjects];
            }
            }];
*/
    }
    
    class func makeFacebookGraphRequest(path: String, parameters: [NSObject: AnyObject]?, block: (AnyObject) -> Void) {
        let request = FBSDKGraphRequest(graphPath: path, parameters: parameters)
        request.startWithCompletionHandler { (connection, result, error) -> Void in
            if UserUtils.noFacebookError(error) {
                block(result)
            }
        }
    }
    
    // This function checks that there is no Facebook error returned from a request, and if there is handles logging the user out if the session is invalid.
    private class func noFacebookError(error: NSError?) -> Bool {
        if let err = error {
            if let errDict = error!.userInfo as? [String: AnyObject] {
                if let errDict2 = errDict["error"] as? [String: AnyObject] {
                    if let type = errDict2["type"] as? String {
                        if type == "OAuthException" {
                            PFFacebookUtils.unlinkUserInBackground(PFUser.currentUser()!)
                            NSLog("Facebook session was invalidated")
                        }
                    }
                }
            }
            NSLog("Facebook error detected: %@", error!)
            return false
        }
        return true
    }
    
    private class func needFacebookInfo(user: PFUser) -> Bool {
        if user.isNew || user["fbid"] == nil {
            return true
        }
        //WARN: This shouldn't always return true
        return true
    }
    
    private class func getFacebookInfo(user: PFUser, block: (Void) -> Void) {
        UserUtils.makeFacebookGraphRequest("me?fields=id,name,first_name", parameters: nil, block: { (result) -> Void in
            if let userDict = result as? [String: String] {
                let user = PFUser.currentUser()!
                user["fbid"] = userDict["id"]
                user["firstName"] = userDict["first_name"]
                user["name"] = userDict["name"]
                user["friendsIds"] = [String]()
                
                // Synchronously save the user for the first time login
                user.saveEventually()
            }
            block()
        })
    }
    
}