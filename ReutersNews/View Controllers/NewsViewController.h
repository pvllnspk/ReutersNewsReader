//
//  NewsViewController.h
//  ReutersNews
//
//  Created by Barney on 7/13/14.
//  Copyright (c) 2014 pvllnspk. All rights reserved.
//

#import <UIKit/UIKit.h>

@class WebViewController;

@interface NewsViewController : UITableViewController

@property (strong, nonatomic) WebViewController *webViewController;
@property (strong, nonatomic, setter = setFeedURL:) NSString *feedURL;

@end
