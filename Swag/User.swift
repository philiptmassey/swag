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
import ParseFacebookUtilsV4

enum UserError: ErrorType {
    case NoParseUser
    case NoParseUserKeyMatch(missingKey: String)
}

class User {
    
    var facebookAccessToken: FBSDKAccessToken?
    var parseUser: PFUser?
    
    init() {
        
    }
    
    init(facebookAccessToken: FBSDKAccessToken) {
        self.facebookAccessToken = facebookAccessToken
    }
    
    //MARK: Setters / Getters
    
    func addFriend(facebookId: String) throws {
        NSLog("User: addFriend")
        if let user = self.parseUser {
            if var friends = user.valueForKey("friendsFacebookIds") as? [String] {
                NSLog("Added friend: %@", facebookId)
                friends.append(facebookId)
                user.setValue(friends, forKey: "friendsFacebookIds")
                user.saveEventually()
            } else {
                throw UserError.NoParseUserKeyMatch(missingKey: "friendsFacebookIds")
            }
        } else {
            throw UserError.NoParseUser
        }
    }
    
    func hasFriend(facebookId: String) throws -> Bool {
        NSLog("User: hasFriends")
        if let user = self.parseUser {
            if let friends = user.valueForKey("friendsFacebookIds") as? [String] {
                if friends.contains(facebookId) {
                    return true
                } else {
                    return false
                }
            } else {
                throw UserError.NoParseUserKeyMatch(missingKey: "friendsFacebookIds")
            }
        } else {
            throw UserError.NoParseUser
        }
    }
    
    func removeFriend(facebookId: String) throws {
        NSLog("User: removeFriend")
        if let user = self.parseUser {
            if var friends = user.valueForKey("friendsFacebookIds") as? [String] {
                if let index = friends.indexOf(facebookId) {
                    NSLog("Removed friend: %@", facebookId)
                    friends.removeAtIndex(index)
                    user.setValue(friends, forKey: "friendsFacebookIds")
                    user.saveEventually()
                } else {
                    NSLog("Failed to remove friend: %@", facebookId)
                }
            } else {
                throw UserError.NoParseUserKeyMatch(missingKey: "friendsFacebookIds")
            }
        } else {
            throw UserError.NoParseUser
        }
    }
    
    func subscribeToFriend(facebookId: String) {
        NSLog("User: subscribeToFriend")
        let channel = "channel" + facebookId
        let installation = PFInstallation.currentInstallation()
        installation.addUniqueObject(channel, forKey: "channels")
        installation.saveEventually()
    }
    
    func unsubscribeToFriend(facebookId: String) {
        NSLog("User: unsubscribeToFriend")
        let channel = "channel" + facebookId
        let installation = PFInstallation.currentInstallation()
        installation.removeObject(channel, forKey: "channels")
        installation.saveEventually()
    }
    
    func swag() throws {
        if let user = self.parseUser {
            let facebookId = user.objectForKey("facebookId") as! String
            let channel = "channel" + facebookId
            let firstName = user.objectForKey("firstName") as! String
            let message = firstName + " has turned on his swag!"
            
            let push = PFPush()
            push.setChannel(channel)
            push.setMessage(message)
            push.sendPushInBackground()
        } else {
            throw UserError.NoParseUser
        }
    }
    
    // MARK: Login
    func login(block: (Void) -> Void) {
        NSLog("User: login")
        
        if let token = self.facebookAccessToken {
            PFFacebookUtils.logInInBackgroundWithAccessToken(token, block: { (user, error) -> Void in
                if User.noFacebookError(error) {
                    if let user = user {
                        self.parseUser = user
                        if self.needFacebookInfo() {
                            self.getFacebookInfo(block)
                        } else {
                            block()
                        }
                    } else {
                        NSLog("Error parsing user from Login from Facebook Access Token")
                    }
                }
            })
        } else {
            let permissions = ["user_friends"];
            PFFacebookUtils.logInInBackgroundWithReadPermissions(permissions, block: { (user, error) -> Void in
                if User.noFacebookError(error) {
                    if let user = user {
                        self.parseUser = user
                        if self.needFacebookInfo() {
                            self.getFacebookInfo(block)
                        } else {
                            block()
                        }
                    } else {
                        NSLog("User cancelled login")
                    }
                }
            })
        }
    }
    
    //MARK: Facebook Communication
    
    class func getFacebookFriends(block: ([[String: String]]) -> Void) {
        NSLog("UserUtils: getFacebookFriendIds")
        User.makeFacebookGraphRequest("me?fields=friends", parameters: nil, block: { (result) -> Void in
            var friends = [[String: String]]()
            if let resultDictionary = result as? [String: AnyObject] {
                if let resultFriends = resultDictionary["friends"] as? [String: AnyObject] {
                    if let resultData = resultFriends["data"] as? [[String: String]] {
                        for friendInfo: [String: String] in resultData {
                            friends.append(friendInfo)
                        }
                        friends.sortInPlace({ (left: [String: String], right: [String: String]) -> Bool in
                            return left["name"] < right["name"]
                        })
                    }
                }
            }
            block(friends)
        })
    }
    
    class func makeFacebookGraphRequest(path: String, parameters: [NSObject: AnyObject]?, block: (AnyObject) -> Void) {
        NSLog("UserUtils: makeFacebookGraphRequest")
        let request = FBSDKGraphRequest(graphPath: path, parameters: parameters)
        request.startWithCompletionHandler { (connection, result, error) -> Void in
            if User.noFacebookError(error) {
                block(result)
            }
        }
    }
    
    // This function checks that there is no Facebook error returned from a request, and if there is handles logging the user out if the session is invalid.
    private class func noFacebookError(error: NSError?) -> Bool {
        NSLog("UserUtils: noFacebookError")
        if let err = error {
            if let errDict = err.userInfo as? [String: AnyObject] {
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
    
    func needFacebookInfo() -> Bool { //throws -> UserError {
        NSLog("Utils: needFacebookInfo")
        if let user = self.parseUser {
            if user.isNew || user.valueForKey("facebookId") == nil {
                return true
            }
            return false
        } else {
            NSLog("No parseUser")
            //throw UserError.NoParseUser
            return false
        }
    }
    
    func getFacebookInfo(block: (Void) -> Void) {
        NSLog("UserUtils: getFacebookInfo")
        if let user = self.parseUser {
            User.makeFacebookGraphRequest("me?fields=id,name,first_name", parameters: nil, block: { (result) -> Void in
                if let userDict = result as? [String: String] {
                    user.setValue(userDict["id"], forKey: "facebookId")
                    user.setValue(userDict["first_name"], forKey: "firstName")
                    user.setValue(userDict["name"], forKey: "name")
                    user.setValue([String](), forKey: "friendsFacebookIds")
                    
                    // Asynchronously save the user for the first time login
                    user.saveEventually()
                }
                block()
            })
        }
    }
    
}