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
        NSLog("UserUtils: loginWithAccessToken")
        PFFacebookUtils.logInInBackgroundWithAccessToken(token, block: { (user, error) -> Void in
            if UserUtils.noFacebookError(error) {
                if let user = user {
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
        NSLog("UserUtils: login")
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
    
    class func getFacebookFriendIds(block: ([String]) -> Void) {
        NSLog("UserUtils: getFacebookFriendIds")
        UserUtils.makeFacebookGraphRequest("me?fields=friends", parameters: nil, block: { (result) -> Void in
            var friendIds = [String]()
            if let resultDictionary = result as? [String: AnyObject] {
                if let friends = resultDictionary["friends"] as? [String: AnyObject] {
                    if let friendPairs = friends["data"] as? [[String: String]] {
                        
                        for friendPair in friendPairs {
                            friendIds.append(friendPair["id"]!)
                        }
                    }
                }
            }
            block(friendIds)
        })
    }
    
    class func addFriend(facebookId: String) {
        NSLog("UserUtils: addFriend")
        let user = PFUser.currentUser()
        if let user = PFUser.currentUser() {
            if var friends = user.objectForKey("friendsFacebookIds") as? [String] {
                friends.append(facebookId)
            }
            user.saveEventually()
        }
    }
    
    class func subscribeToFriend(facebookId: String) {
        NSLog("UserUtils: subscribeToFriend")
        let channel = facebookId + "channel"
        let installation = PFInstallation.currentInstallation()
        installation.addUniqueObject(channel, forKey: "channels")
        installation.saveEventually()
    }
    
    class func unsubscribeToFriend(facebookId: String) {
        NSLog("UserUtils: unsubscribeToFriend")
        let channel = facebookId + "channel"
        let installation = PFInstallation.currentInstallation()
        installation.removeObject(channel, forKey: "channels")
        installation.saveEventually()
    }
    
    class func makeFacebookGraphRequest(path: String, parameters: [NSObject: AnyObject]?, block: (AnyObject) -> Void) {
        NSLog("UserUtils: makeFacebookGraphRequest")
        let request = FBSDKGraphRequest(graphPath: path, parameters: parameters)
        request.startWithCompletionHandler { (connection, result, error) -> Void in
            if UserUtils.noFacebookError(error) {
                block(result)
            }
        }
    }
    
    // This function checks that there is no Facebook error returned from a request, and if there is handles logging the user out if the session is invalid.
    private class func noFacebookError(error: NSError?) -> Bool {
        NSLog("UserUtils: noFacebookError")
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
        NSLog("UserUtils: needFacebookInfo")
        if user.isNew || user["fbid"] == nil {
            return true
        }
        //WARN: This shouldn't always return true
        return true
    }
    
    private class func getFacebookInfo(user: PFUser, block: (Void) -> Void) {
        NSLog("UserUtils: getFacebookInfo")
        UserUtils.makeFacebookGraphRequest("me?fields=id,name,first_name", parameters: nil, block: { (result) -> Void in
            if let userDict = result as? [String: String] {
                let user = PFUser.currentUser()!
                user["facebookId"] = userDict["id"]
                user["firstName"] = userDict["first_name"]
                user["name"] = userDict["name"]
                user["friendsFacebookIds"] = [String]()
                
                // Synchronously save the user for the first time login
                user.saveEventually()
            }
            block()
        })
    }
    
}