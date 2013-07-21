//
//  ViewController.m
//  ReutersNewsFeedsReader
//
//  Created by Barney on 7/13/13.
//  Copyright (c) 2013 pvllnspk. All rights reserved.
//

#import "WebViewController.h"
#import "MWFeedItem.h"
#import "TFHpple.h"
#import "NSString+Additions.h"
#import "RNController.h"
#import "RNActivityViewController.h"

typedef NS_ENUM(NSInteger, FeedTransition)
{
    FeedTransitionNext,
    FeedTransitionPrevious
};

@interface WebViewController() <UIGestureRecognizerDelegate, UIWebViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;

- (IBAction)tabButtonPressed:(id)sender;

@end

@implementation WebViewController
{
     MWFeedItem *_currentFeed;
}


#pragma mark -
#pragma mark Set Feed

-(void)setFeed:(MWFeedItem *)feed
{
    if(!feed)return;
    
    _currentFeed = feed;
    
    //clear the webview content
    [_webView stringByEvaluatingJavaScriptFromString:@"document.open();document.close();"];
    
    //load a local html file
    NSString* filePath = [RNController isPad]?[[NSBundle mainBundle] pathForResource:@"view_pad" ofType:@"html"]:[[NSBundle mainBundle] pathForResource:@"view_phone" ofType:@"html"];
    NSMutableString* html = [NSMutableString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    [html replaceOccurrencesOfString:@"[title]" withString:[feed.title stringByStrippingHTML] options:0 range:NSMakeRange(0, html.length)];
    [_webView loadHTMLString:html baseURL:nil];
    
    //download asynchronously feed data and update the webview in the main thread
    dispatch_queue_t backgroundQueue = dispatch_queue_create("dispatch_queue_#1", 0);
    dispatch_async(backgroundQueue, ^{
        
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:feed.link] cachePolicy:NSURLCacheStorageAllowed timeoutInterval:15];
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSString *result;
        NSString *feedText = [[NSString alloc]init];
        
        if (data && !error)
        {
             //extract images data
            result = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
            NSString *textXpathQueryString = @"//div[@id='articleImage']";
            NSArray *textNodes = [doc searchWithXPathQuery:textXpathQueryString];
            
            if([textNodes count]>0)
            {
                TFHppleElement *element = [textNodes objectAtIndex:0];
                TFHppleElement *childElement =[element firstChildWithTagName: @"img"];
                feedText = [feedText stringByAppendingString:[NSString stringWithFormat:@"<img src='%@' border='0'/>",[childElement objectForKey:@"src"]]];
                feedText = [feedText stringByAppendingString:[NSString stringWithFormat:@"<p class='alt'>%@</p>",[[childElement objectForKey:@"alt"] stringByStrippingHTML]]];
            }
            
            //TODO: didn't manage to parse it with the TFHpple => extract midArticle data manually
            for(int i=0;i<20;i++){
                NSString *str = [result stringBetweenString:[NSString stringWithFormat:@"midArticle_%d",i] andString:[NSString stringWithFormat:@"midArticle_%d",i+1]];
                if(str){
                    
                    feedText = [feedText stringByAppendingString:str];
                    feedText = [feedText stringByAppendingString:@"\n\n\t"];
                    
                }
            }
            
            for(int i=0;i<20;i++){
                NSString *str = [result lastStringBetweenString:[NSString stringWithFormat:@"midArticle_%d",i] andString:[NSString stringWithFormat:@"midArticle_%d",i+1]];
                if(str && [feedText rangeOfString:str].location == NSNotFound){
                    
                    feedText = [feedText stringByAppendingString:str];
                    feedText = [feedText stringByAppendingString:@"\n\n\t"];
                    
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [html replaceOccurrencesOfString:@"Loading..." withString:feedText options:0 range:NSMakeRange(0, html.length)];
            [_webView loadHTMLString:html baseURL:nil];
            
        });
    });
}


#pragma mark -
#pragma mark View Lifecycle

-(void)viewDidLoad
{
    [_webView setDelegate:self];
    //set offset for the webview
    [[_webView scrollView] setContentInset:UIEdgeInsetsMake(0, 0, 40, 0)];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:NO];
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
}


#pragma mark -
#pragma mark WebView Callbacks

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}


#pragma mark -
#pragma mark User Interaction Callbacks

- (IBAction)tabButtonPressed:(id)sender
{
    int buttonTag = [sender tag];
    switch (buttonTag) {
        case 0:
            
            [self back];
            
            break;
        case 1:
            
            [self transitionToType:FeedTransitionPrevious];
            
            break;
        case 2:
            
            [self transitionToType:FeedTransitionNext];
            
            break;
        case 3:
        {
            NSURL *url = [NSURL URLWithString:_currentFeed.link];
            UIActivityViewController *activityViewController = [RNActivityViewController controllerForURL:url];
            if ([RNController isPad])
            {
//                _popoverController = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
//                [_popoverController presentPopoverFromRect:self.shareButton.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
                [self.navigationController presentViewController:activityViewController animated:YES completion:nil];
            
            }
            else
            {
                [self.navigationController presentViewController:activityViewController animated:YES completion:nil];
            }
        }
            break;
    }
}

-(void)back
{
    [self.navigationController popViewControllerAnimated:YES];
}

-(void)transitionToType:(FeedTransition) transitionType
{
    switch (transitionType) {
        case FeedTransitionNext:
            
            [self setFeed:[self nextFeed]];
            
            break;
        case FeedTransitionPrevious:
            
            [self setFeed:[self previousFeed]];
            
            break;
        default:
            break;
    }
}


#pragma mark -
#pragma mark Utility Methods

- (MWFeedItem *)nextFeed;
{
    int currentIndex = [self indexOfFeed:_currentFeed];
    if (currentIndex == _feeds.count-1 || currentIndex == NSNotFound) return nil;
    return _feeds[++currentIndex];
}

- (MWFeedItem *)previousFeed;
{
    int currentIndex = [self indexOfFeed:_currentFeed];
    if (currentIndex == 0 || currentIndex == NSNotFound) return nil;
    return _feeds[--currentIndex];
}

- (int)indexOfFeed:(MWFeedItem *)feed
{
    int index = 0;
    for (MWFeedItem *f in _feeds)
    {
        if ([feed.identifier isEqualToString:f.identifier])
        {
            return index;
        }
        index++;
    }
    return NSNotFound;
}

@end
