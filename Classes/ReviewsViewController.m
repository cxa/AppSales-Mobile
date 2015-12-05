//
//  ReviewsViewController.m
//  AppSales
//
//  Created by Ole Zorn on 30.07.11.
//  Copyright 2011 omz:software. All rights reserved.
//

#import "ReviewsViewController.h"
#import "ReviewDownloadManager.h"
#import "ReviewListViewController.h"
#import "ASAccount.h"
#import "Product.h"

@implementation ReviewsViewController

@synthesize reviewSummaryView, reviewsPopover;

- (id)initWithAccount:(ASAccount *)anAccount {
	self = [super initWithAccount:anAccount];
	if (self) {
		self.title = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? NSLocalizedString(@"Reviews", nil) : [account displayName];
		self.tabBarItem.image = [UIImage imageNamed:@"Reviews.png"];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reviewDownloadProgressDidChange:) name:ReviewDownloadManagerDidUpdateProgressNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willShowPasscodeLock:) name:ASWillShowPasscodeLockNotification object:nil];
	}
	
	[self performSelector:@selector(setEdgesForExtendedLayout:) withObject:[NSNumber numberWithInteger:0]];
	
	return self;
}

- (void)willShowPasscodeLock:(NSNotification *)notification {
	[super willShowPasscodeLock:notification];
	if (self.reviewsPopover.popoverVisible) {
		[self.reviewsPopover dismissPopoverAnimated:NO];
	}
}

- (void)loadView {
	[super loadView];
	
	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", nil) style:UIBarButtonItemStylePlain target:self action:nil];
	self.navigationItem.backBarButtonItem = backButton;
	
	self.reviewSummaryView = [[ReviewSummaryView alloc] initWithFrame:self.topView.frame];
	reviewSummaryView.dataSource = self;
	reviewSummaryView.delegate = self;
	reviewSummaryView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	[self.view addSubview:reviewSummaryView];
	
	downloadReviewsButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(downloadReviews:)];
	downloadReviewsButtonItem.enabled = ![[ReviewDownloadManager sharedManager] isDownloading];
	self.navigationItem.rightBarButtonItem = downloadReviewsButtonItem;
	
	if ([self shouldShowStatusBar]) {
		self.progressBar.progress = [[ReviewDownloadManager sharedManager] downloadProgress];
		self.statusLabel.text = NSLocalizedString(@"Downloading Reviews...", nil);
	}
}

- (void)viewDidUnload {
	[super viewDidUnload];
	self.reviewSummaryView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (BOOL)shouldShowStatusBar {
	return [[ReviewDownloadManager sharedManager] isDownloading];
}

- (void)reviewDownloadProgressDidChange:(NSNotification *)notification {
	downloadReviewsButtonItem.enabled = ![[ReviewDownloadManager sharedManager] isDownloading];
	[self showOrHideStatusBar];
	if (!self.account.isDownloadingReports) {
		self.progressBar.progress = [[ReviewDownloadManager sharedManager] downloadProgress];
		if ([[ReviewDownloadManager sharedManager] isDownloading]) {
			self.statusLabel.text = NSLocalizedString(@"Downloading Reviews...", nil);
		} else {
			self.statusLabel.text = NSLocalizedString(@"Finished", nil);
		}
	}
}

- (NSSet *)entityNamesTriggeringReload {
	return [NSSet setWithObjects:@"Review", @"Product", nil];
}

- (void)reloadData {
	[super reloadData];
	self.visibleProducts = [self.products filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(Product *product, NSDictionary *bindings) {
		return !(product.parentSKU.length > 1); // In-App Purchases can't have reviews, so don't include them.
	}]];
	[self reloadTableView];
	[self.reviewSummaryView reloadDataAnimated:NO];
}

- (void)downloadReviews:(id)sender {
	NSArray *productReviewsToDownload = [self.visibleProducts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(Product *product, NSDictionary *bindings) {
		return !product.hidden.boolValue; // Don't bother downloading reviews for hidden apps.
	}]];
	[[ReviewDownloadManager sharedManager] downloadReviewsForProducts:productReviewsToDownload];
}

- (void)stopDownload:(id)sender {
	self.stopButtonItem.enabled = NO;
	[[ReviewDownloadManager sharedManager] cancelAllDownloads];
	self.statusLabel.text = NSLocalizedString(@"Cancelled", nil);
}

- (NSUInteger)reviewSummaryView:(ReviewSummaryView *)view numberOfReviewsForRating:(NSInteger)rating {
	if (!self.account) return 0;
	
	NSFetchRequest *reviewsCountFetchRequest = [[NSFetchRequest alloc] init];
	[reviewsCountFetchRequest setEntity:[NSEntityDescription entityForName:@"Review" inManagedObjectContext:self.account.managedObjectContext]];

	NSMutableString *pred = [NSMutableString stringWithString:@"rating == %@"];
	NSMutableArray *args = [NSMutableArray arrayWithArray:self.selectedProducts];
	[args insertObject:[NSNumber numberWithInteger:rating] atIndex:0];
	
	if (![self.selectedProducts count]) {
		[pred appendString:@" AND product.account = %@"];
		[args addObject:self.account];
		[reviewsCountFetchRequest setPredicate:[NSPredicate predicateWithFormat:pred argumentArray:args]];
	} else {
		[pred appendString:@" AND (product == nil"];
		for (Product *p __attribute__((unused)) in self.selectedProducts) {
			[pred appendString:@" OR product == %@"];
		}
		[pred appendString:@")"];
		[reviewsCountFetchRequest setPredicate:[NSPredicate predicateWithFormat:pred argumentArray:args]];
	}
	NSUInteger numberOfReviewsForRating = [self.account.managedObjectContext countForFetchRequest:reviewsCountFetchRequest error:NULL];	
	return numberOfReviewsForRating;
}

- (NSUInteger)reviewSummaryView:(ReviewSummaryView *)view numberOfUnreadReviewsForRating:(NSInteger)rating {
	if (!self.account) return 0;
	
	NSFetchRequest *reviewsCountFetchRequest = [[NSFetchRequest alloc] init];
	[reviewsCountFetchRequest setEntity:[NSEntityDescription entityForName:@"Review" inManagedObjectContext:self.account.managedObjectContext]];
	
	NSMutableString *pred = [NSMutableString stringWithString:@"rating == %@ AND unread = TRUE"];
	NSMutableArray *args = [NSMutableArray arrayWithArray:self.selectedProducts];
	[args insertObject:[NSNumber numberWithInteger:rating] atIndex:0];
	
	if (![self.selectedProducts count]) {
		[pred appendString:@" AND product.account = %@"];
		[args addObject:self.account];
		[reviewsCountFetchRequest setPredicate:[NSPredicate predicateWithFormat:pred argumentArray:args]];
	} else {
		[pred appendString:@" AND (product == nil"];
		for (Product *p __attribute__((unused)) in self.selectedProducts) {
			[pred appendString:@" OR product == %@"];
		}
		[pred appendString:@")"];
		[reviewsCountFetchRequest setPredicate:[NSPredicate predicateWithFormat:pred argumentArray:args]];
	}
	NSUInteger numberOfUnreadReviewsForRating = [self.account.managedObjectContext countForFetchRequest:reviewsCountFetchRequest error:NULL];	
	return numberOfUnreadReviewsForRating;
}

- (void)reviewSummaryView:(ReviewSummaryView *)view didSelectRating:(NSInteger)rating {
	if (!self.account) return;
	
	ReviewListViewController *vc = [[ReviewListViewController alloc] initWithAccount:self.account products:self.selectedProducts rating:rating];
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
		[self.navigationController pushViewController:vc animated:YES];
	} else {
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
		self.reviewsPopover = [[UIPopoverController alloc] initWithContentViewController:nav];
		[reviewsPopover presentPopoverFromRect:[reviewSummaryView barFrameForRating:rating]	inView:reviewSummaryView permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
	}
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
	[super tableView:tableView didDeselectRowAtIndexPath:indexPath];
	[self.reviewSummaryView reloadDataAnimated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	[self.reviewSummaryView reloadDataAnimated:YES];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
	[super handleLongPress:gestureRecognizer];
	[self.reviewSummaryView reloadDataAnimated:YES];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

@end
