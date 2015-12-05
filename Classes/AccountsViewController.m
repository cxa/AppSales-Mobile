//
//  AccountsViewController.m
//  AppSales
//
//  Created by Ole Zorn on 30.06.11.
//  Copyright 2011 omz:software. All rights reserved.
//

#import "AccountsViewController.h"
#import "AccountsViewController+VendorID.h"
#import "SalesViewController.h"
#import "ReviewsViewController.h"
#import "SSKeychain.h"
#import "ASAccount.h"
#import "Report.h"
#import "Product.h"
#import "CurrencyManager.h"
#import "ReportDownloadCoordinator.h"
#import "MBProgressHUD.h"
#import "ReportImportOperation.h"
#import "PaymentsViewController.h"
#import "BadgedCell.h"
#import "UIImage+Tinting.h"
#import "AboutViewController.h"
#import "AccountStatusView.h"
#import "PromoCodesViewController.h"
#import "PromoCodesLicenseViewController.h"
#import "KKPasscodeLock.h"
#import "IconManager.h"
#import "ZIPArchive.h"

#define kAddNewAccountEditorIdentifier		@"AddNewAccountEditorIdentifier"
#define kEditAccountEditorIdentifier		@"EditAccountEditorIdentifier"
#define kSettingsEditorIdentifier			@"SettingsEditorIdentifier"
#define kUpdateExchangeRatesButton			@"UpdateExchangeRatesButton"
#define kPasscodeLockButton					@"PasscodeLockButton"
#define kImportReportsButton				@"ImportReportsButton"
#define kExportReportsButton				@"ExportReportsButton"
#define	kDeleteAccountButton				@"DeleteAccount"
#define kAlertTagConfirmImport				1
#define kAlertTagExportCompleted			2
#define kAlertTagConfirmDelete				3
#define kAccountTitle						@"title"
#define kKeychainServiceIdentifier			@"iTunesConnect"


@implementation AccountsViewController

@synthesize managedObjectContext, accounts, selectedAccount, refreshButtonItem, delegate, documentInteractionController;

- (void)viewDidLoad {
	[super viewDidLoad];
	
	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", nil) style:UIBarButtonItemStylePlain target:self action:nil];
	self.navigationItem.backBarButtonItem = backButton;
	
	self.refreshButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(downloadReports:)];
	UIBarButtonItem *settingsButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil) style:UIBarButtonItemStylePlain target:self action:@selector(showSettings)];
	UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
	[infoButton addTarget:self action:@selector(showInfo:) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem *infoButtonItem = [[UIBarButtonItem alloc] initWithCustomView:infoButton];
	
	self.toolbarItems = [NSArray arrayWithObjects:infoButtonItem, flexSpace, settingsButtonItem, nil];
	self.navigationItem.rightBarButtonItem = refreshButtonItem;
	
	self.title = NSLocalizedString(@"AppSales", nil);
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addNewAccount)];
	self.navigationItem.leftBarButtonItem = addButton;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextDidChange:) name:NSManagedObjectContextObjectsDidChangeNotification object:[self managedObjectContext]];
	
	[[ReportDownloadCoordinator sharedReportDownloadCoordinator] addObserver:self forKeyPath:@"isBusy" options:NSKeyValueObservingOptionNew context:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iconCleared:) name:IconManagerClearedIconNotification object:nil];
	
	[self reloadAccounts];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"isBusy"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.refreshButtonItem.enabled = ![[ReportDownloadCoordinator sharedReportDownloadCoordinator] isBusy];
		});
	}
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (![[ReportDownloadCoordinator sharedReportDownloadCoordinator] isBusy] && [self.accounts count] == 0) {
		[self addNewAccount];
	}
}

- (void)contextDidChange:(NSNotification *)notification {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.1];
}

- (void)reloadAccounts {
	NSFetchRequest *accountsFetchRequest = [[NSFetchRequest alloc] init];
	[accountsFetchRequest setEntity:[NSEntityDescription entityForName:@"Account" inManagedObjectContext:self.managedObjectContext]];
	[accountsFetchRequest setSortDescriptors:[NSArray arrayWithObjects:[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES], [[NSSortDescriptor alloc] initWithKey:@"username" ascending:YES], nil]];
	self.accounts = [self.managedObjectContext executeFetchRequest:accountsFetchRequest error:NULL];
	
	[self.tableView reloadData];
}

- (void)downloadReports:(id)sender {
	for (ASAccount *account in self.accounts) {
		if (account.password && account.password.length > 0) { //Only download reports for accounts with login
			if (!account.vendorID || account.vendorID.length == 0) {
				[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Vendor ID Missing", nil) 
											 message:[NSString stringWithFormat:NSLocalizedString(@"You have not entered a vendor ID for the account \"%@\". Please go to the account's settings and fill in the missing information.", nil), [account displayName]] 
											delegate:nil 
								   cancelButtonTitle:NSLocalizedString(@"OK", nil) 
								   otherButtonTitles:nil] show];
			} else {
				[[ReportDownloadCoordinator sharedReportDownloadCoordinator] downloadReportsForAccount:account];
			}
		}
	}
}

- (void)showInfo:(id)sender {
	AboutViewController *aboutViewController = [[AboutViewController alloc] init];
	UINavigationController *aboutNavController = [[UINavigationController alloc] initWithRootViewController:aboutViewController];
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		aboutNavController.modalPresentationStyle = UIModalPresentationFormSheet;
	} else {
		aboutNavController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
	}
	[self presentViewController:aboutNavController animated:YES completion:nil];
}


- (void)viewDidUnload {
	[super viewDidUnload];
}


#pragma mark - Table view

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) return nil;
	
	if ([self.accounts count] == 0) {
		return nil;
	}
	ASAccount *account = [self.accounts objectAtIndex:section];
	NSString *title = account.title;
	if (!title || [title isEqualToString:@""]) {
		title = account.username;
	}
	return title;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) return 1;
	
	if ([self.accounts count] == 0) {
		return 1;
	}
	return [self.accounts count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) return self.accounts.count;
	
	if ([self.accounts count] == 0) {
		return 0;
	}
	return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"Cell";
	BadgedCell *cell = (BadgedCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[BadgedCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
	}
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		cell.textLabel.text = [[self.accounts objectAtIndex:indexPath.row] displayName];
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
		return cell;
	}
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	if (indexPath.row == 0) {
		NSInteger badge = [[[self.accounts objectAtIndex:indexPath.section] reportsBadge] integerValue];
		cell.textLabel.text = NSLocalizedString(@"Sales and Trends", nil);
		cell.badgeCount = badge;
		cell.imageView.image = [UIImage imageNamed:@"Sales.png"];
		cell.imageView.highlightedImage = [UIImage as_tintedImageNamed:@"Sales.png" color:[UIColor whiteColor]];
	} else if (indexPath.row == 1) {
		NSInteger badge = [[[self.accounts objectAtIndex:indexPath.section] paymentsBadge] integerValue];
		cell.textLabel.text = NSLocalizedString(@"Payments", nil);
		cell.badgeCount = badge;
		cell.imageView.image = [UIImage imageNamed:@"Payments.png"];
		cell.imageView.highlightedImage = [UIImage as_tintedImageNamed:@"Payments.png" color:[UIColor whiteColor]];
	} else if (indexPath.row == 2) {
		cell.textLabel.text = NSLocalizedString(@"Customer Reviews", nil);
		cell.imageView.image = [UIImage imageNamed:@"Reviews.png"];
		cell.imageView.highlightedImage = [UIImage as_tintedImageNamed:@"Reviews.png" color:[UIColor whiteColor]];
		
		ASAccount *account = [self.accounts objectAtIndex:indexPath.section];
		NSFetchRequest *unreadReviewsRequest = [[NSFetchRequest alloc] init];
		[unreadReviewsRequest setEntity:[NSEntityDescription entityForName:@"Review" inManagedObjectContext:[self managedObjectContext]]];
		[unreadReviewsRequest setPredicate:[NSPredicate predicateWithFormat:@"product.account == %@ AND unread == TRUE", account]];
		cell.badgeCount = [[self managedObjectContext] countForFetchRequest:unreadReviewsRequest error:NULL];
	} else if (indexPath.row == 3) {
		cell.textLabel.text = NSLocalizedString(@"Promo Codes", nil);
		cell.imageView.image = [UIImage imageNamed:@"PromoCodes.png"];
		cell.imageView.highlightedImage = [UIImage as_tintedImageNamed:@"PromoCodes.png" color:[UIColor whiteColor]];
		cell.badgeCount = 0;
	} else if (indexPath.row == 4) {
		cell.textLabel.text = NSLocalizedString(@"Account", nil);
		cell.imageView.image = [UIImage imageNamed:@"Account.png"];
		cell.imageView.highlightedImage = [UIImage as_tintedImageNamed:@"Account.png" color:[UIColor whiteColor]];
		cell.badgeCount = 0;
	}	
	return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	//iPad only
	ASAccount *account = [self.accounts objectAtIndex:indexPath.row];
	[self editAccount:account];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) return nil;
	
	if ([self.accounts count] == 0) {
		return nil;
	}
	ASAccount *account = [self.accounts objectAtIndex:section];
	return [[AccountStatusView alloc] initWithFrame:CGRectMake(0, 0, 320, 26) account:account];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	return 26.0;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 44.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		if (self.delegate) {
			ASAccount *account = [self.accounts objectAtIndex:indexPath.row];
			[self.delegate accountsViewController:self didSelectAccount:account];
		}
		return;
	}
	ASAccount *account = [self.accounts objectAtIndex:indexPath.section];
	if (indexPath.row == 0) {
		SalesViewController *salesViewController = [[SalesViewController alloc] initWithAccount:account];
		[self.navigationController pushViewController:salesViewController animated:YES];
	} else if (indexPath.row == 1) {
		PaymentsViewController *paymentsViewController = [[PaymentsViewController alloc] initWithAccount:account];
		[self.navigationController pushViewController:paymentsViewController animated:YES];
	} else if (indexPath.row == 2) {
		ReviewsViewController *reviewsViewController = [[ReviewsViewController alloc] initWithAccount:account];
		[self.navigationController pushViewController:reviewsViewController animated:YES];
	} else if (indexPath.row == 3) {
		PromoCodesViewController *promoCodesViewController = [[PromoCodesViewController alloc] initWithAccount:account];
		[self.navigationController pushViewController:promoCodesViewController animated:YES];
	} else if (indexPath.row == 4) {
		[self editAccount:account];
	}
}

#pragma mark -

- (void)deleteAccount:(NSManagedObject *)account {
	if (account) {
		NSManagedObjectContext *context = self.managedObjectContext;
		[context deleteObject:account];
		[MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
		[self reloadAccounts];
		[self.navigationController popViewControllerAnimated:YES];
	}
}

- (NSArray *)accountSectionsFor:(ASAccount *)account {
	FieldSpecifier *usernameField = [FieldSpecifier emailFieldWithKey:kAccountUsername title:NSLocalizedString(@"Email", nil) defaultValue:account.username ?: @""];
	FieldSpecifier *passwordField = [FieldSpecifier passwordFieldWithKey:kAccountPassword title:NSLocalizedString(@"Password", nil) defaultValue:account.password ?: @""];
	FieldSectionSpecifier *loginSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObjects:usernameField, passwordField, nil]
																			 title:NSLocalizedString(@"iTunes Connect Login", nil)
																	   description:nil];
	
	FieldSpecifier *appPasswordField = [FieldSpecifier passwordFieldWithKey:kAccountAppPassword title:NSLocalizedString(@"Password", nil) defaultValue:account.appPassword ?: @""];
	FieldSpecifier *generateAppPasswordButtonField = [FieldSpecifier buttonFieldWithKey:@"GenerateAppPasswordButton" title:NSLocalizedString(@"Generate App-Specific Password...", nil)];
	FieldSectionSpecifier *appPasswordSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObjects:appPasswordField, generateAppPasswordButtonField, nil]
																				   title:NSLocalizedString(@"App-Specific Password", nil)
																	   description:NSLocalizedString(@"An app-specific password is required in order to fetch reports. Tap the button above to open the “Manage your Apple ID” web page.", nil)];
	
	FieldSpecifier *vendorIDField = [FieldSpecifier numericFieldWithKey:kAccountVendorID title:NSLocalizedString(@"Vendor ID", nil) defaultValue:account.vendorID ?: @""];
	vendorIDField.placeholder = @"8XXXXXXX";
	FieldSpecifier *selectVendorIDButtonField = [FieldSpecifier buttonFieldWithKey:@"SelectVendorIDButton" title:NSLocalizedString(@"Auto-Fill Vendor ID...", nil)];
	FieldSectionSpecifier *vendorIDSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObjects:vendorIDField, selectVendorIDButtonField, nil]
																			 title:NSLocalizedString(@"Vendor ID", nil)
																	   description:NSLocalizedString(@"You can find your Vendor ID at the top of the “Payments and Financial Reports” module in iTunes Connect.", nil)];
	
	return @[loginSection, appPasswordSection, vendorIDSection];
}

- (void)addNewAccount {
	FieldSpecifier *titleField = [FieldSpecifier textFieldWithKey:kAccountTitle title:@"Description" defaultValue:@""];
	titleField.placeholder = NSLocalizedString(@"optional", nil);
	FieldSectionSpecifier *titleSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObject:titleField] title:nil description:nil];
	
	NSMutableArray *sections = [[NSMutableArray alloc] initWithArray:[self accountSectionsFor:nil]];
	[sections insertObject:titleSection atIndex:0];
	
	FieldEditorViewController *addAccountViewController = [[FieldEditorViewController alloc] initWithFieldSections:sections title:NSLocalizedString(@"New Account",nil)];
	addAccountViewController.cancelButtonTitle = NSLocalizedString(@"Cancel", nil);
	addAccountViewController.doneButtonTitle = NSLocalizedString(@"Done", nil);
	addAccountViewController.delegate = self;
	addAccountViewController.editorIdentifier = kAddNewAccountEditorIdentifier;
	UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:addAccountViewController];
	
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
		
	}
	[self presentViewController:navigationController animated:YES completion:nil];
}

- (void)editAccount:(ASAccount *)account {
	self.selectedAccount = account;
	
	FieldSpecifier *titleField = [FieldSpecifier textFieldWithKey:kAccountTitle title:@"Description" defaultValue:account.title ?: @""];
	titleField.placeholder = NSLocalizedString(@"optional", nil);
	
	FieldSpecifier *loginSubsectionField = [FieldSpecifier subsectionFieldWithSections:[self accountSectionsFor:account] key:@"iTunesConnect" title:NSLocalizedString(@"iTunes Connect Login", nil)];
	FieldSectionSpecifier *titleSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObjects:titleField, loginSubsectionField, nil] title:nil description:nil];
	
	FieldSpecifier *importButtonField = [FieldSpecifier buttonFieldWithKey:kImportReportsButton title:NSLocalizedString(@"Import Reports...", nil)];
	FieldSpecifier *exportButtonField = [FieldSpecifier buttonFieldWithKey:kExportReportsButton title:NSLocalizedString(@"Export Reports...", nil)];
	FieldSectionSpecifier *importExportSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObjects:importButtonField, exportButtonField, nil] 
																					title:nil 
																			  description:nil /*NSLocalizedString(@"Use iTunes file sharing to import report files from your computer.",nil)*/];
	
	NSMutableArray *productFields = [NSMutableArray array];
	NSArray *allProducts = [[account.products allObjects] sortedArrayUsingComparator:^NSComparisonResult(Product *product1, Product *product2) {
		NSInteger productID1 = product1.productID.integerValue;
		NSInteger productID2 = product2.productID.integerValue;
		if (productID1 < productID2) {
			return (NSComparisonResult)NSOrderedDescending;
		} else if (productID1 > productID2) {
			return (NSComparisonResult)NSOrderedAscending;
		}
		return (NSComparisonResult)NSOrderedSame;
	}];
	
	for (Product *product in allProducts) {
		FieldSpecifier *productNameField = [FieldSpecifier textFieldWithKey:[NSString stringWithFormat:@"product.name.%@", product.productID] title:NSLocalizedString(@"Name", nil) defaultValue:[product displayName]];
		FieldSpecifier *hideProductField = [FieldSpecifier switchFieldWithKey:[NSString stringWithFormat:@"product.hidden.%@", product.productID] title:NSLocalizedString(@"Hide in Dashboard", nil) defaultValue:[product.hidden boolValue]];
		FieldSpecifier *reloadProductInfoField = [FieldSpecifier buttonFieldWithKey:[NSString stringWithFormat:@"product.reload.%@", product.productID] title:NSLocalizedString(@"Reload App Icon...", nil)];
		FieldSectionSpecifier *productSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObjects:productNameField, hideProductField, reloadProductInfoField, nil] title:nil description:nil];
		FieldSpecifier *showInAppStoreField = [FieldSpecifier buttonFieldWithKey:[NSString stringWithFormat:@"product.appstore.%@", product.productID] title:NSLocalizedString(@"Show in App Store...", nil)];
		NSString *productFooter = [NSString stringWithFormat:@"Current version: %@\nApple ID: %@", ((product.currentVersion) ? product.currentVersion : @"N/A"), product.productID];
		FieldSectionSpecifier *showInAppStoreSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObject:showInAppStoreField] title:nil description:productFooter];
		FieldSpecifier *productSectionField = [FieldSpecifier subsectionFieldWithSections:[NSArray arrayWithObjects:productSection, showInAppStoreSection, nil] key:[NSString stringWithFormat:@"product.section.%@", product.productID] title:[product defaultDisplayName]];
		[productFields addObject:productSectionField];
	}
	FieldSectionSpecifier *productsSection = [FieldSectionSpecifier sectionWithFields:productFields title:NSLocalizedString(@"Manage Apps", nil) description:nil];
	FieldSpecifier *manageProductsSectionField = [FieldSpecifier subsectionFieldWithSection:productsSection key:@"ManageProducts"];
	FieldSectionSpecifier *manageProductsSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObject:manageProductsSectionField] title:nil description:nil];
	if ([allProducts count] == 0) {
		productsSection.description = NSLocalizedString(@"This account does not contain any apps yet. Import or download reports first.", nil);
	}
	
	FieldSpecifier *deleteAccountButtonField = [FieldSpecifier buttonFieldWithKey:kDeleteAccountButton title:NSLocalizedString(@"Delete Account...", nil)];
	FieldSectionSpecifier *deleteAccountSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObject:deleteAccountButtonField] title:nil description:nil];
	
	NSArray *sections = [NSArray arrayWithObjects:titleSection, importExportSection, manageProductsSection, deleteAccountSection, nil];
	FieldEditorViewController *editAccountViewController = [[FieldEditorViewController alloc] initWithFieldSections:sections title:NSLocalizedString(@"Account Details",nil)];
	editAccountViewController.doneButtonTitle = nil;
	editAccountViewController.delegate = self;
	editAccountViewController.editorIdentifier = kEditAccountEditorIdentifier;
	editAccountViewController.context = account;
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
		editAccountViewController.hidesBottomBarWhenPushed = YES;
	}
	
	editAccountViewController.preferredContentSize = CGSizeMake(320, 480);
	
	[self.navigationController pushViewController:editAccountViewController animated:YES];
}

- (void)showSettings {
	// main section
	passcodeLockField = [FieldSpecifier buttonFieldWithKey:kPasscodeLockButton title:NSLocalizedString(@"Passcode Lock", nil)];
	passcodeLockField.shouldDisplayDisclosureIndicator = YES;
	if ([[KKPasscodeLock sharedLock] isPasscodeRequired]) {
		passcodeLockField.defaultValue = @"On";
	} else {
		passcodeLockField.defaultValue = @"Off";
	}
	
	NSString *baseCurrency = [[CurrencyManager sharedManager] baseCurrency];
	NSArray *availableCurrencies = [[CurrencyManager sharedManager] availableCurrencies];
	NSMutableArray *currencyFields = [NSMutableArray array];
	for (NSString *currency in availableCurrencies) {
		FieldSpecifier *currencyField = [FieldSpecifier checkFieldWithKey:[NSString stringWithFormat:@"currency.%@", currency] title:currency defaultValue:[baseCurrency isEqualToString:currency]];
		[currencyFields addObject:currencyField];
	}
	FieldSectionSpecifier *currencySection = [FieldSectionSpecifier sectionWithFields:currencyFields
																				title:NSLocalizedString(@"Currency", nil)
																		  description:nil];
	currencySection.exclusiveSelection = YES;
	FieldSpecifier *currencySectionField = [FieldSpecifier subsectionFieldWithSection:currencySection key:@"currency"];
	FieldSpecifier *updateExchangeRatesButtonField = [FieldSpecifier buttonFieldWithKey:kUpdateExchangeRatesButton title:NSLocalizedString(@"Update Exchange Rates Now", nil)];
	FieldSectionSpecifier *generalSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObjects:passcodeLockField, currencySectionField, updateExchangeRatesButtonField, nil]
																			   title:NSLocalizedString(@"General", nil)
																	  description:NSLocalizedString(@"Exchange rates will automatically be refreshed periodically.", nil)];
	
	
	FieldSpecifier *downloadPaymentsField = [FieldSpecifier switchFieldWithKey:kSettingDownloadPayments title:NSLocalizedString(@"Download Payments", nil) defaultValue:[[NSUserDefaults standardUserDefaults] boolForKey:kSettingDownloadPayments]];
	FieldSpecifier *deleteCookiesField = [FieldSpecifier switchFieldWithKey:kSettingDeleteCookies title:NSLocalizedString(@"Delete Cookies", nil) defaultValue:[[NSUserDefaults standardUserDefaults] boolForKey:kSettingDeleteCookies]];
	FieldSectionSpecifier *paymentsSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObjects:downloadPaymentsField, deleteCookiesField, nil]
																				title:NSLocalizedString(@"Payments", nil)
																		  description:NSLocalizedString(@"Delete Cookies forces accounts with Two-Step Verification to re-verify their identity each time that payments are downloaded.", nil)];
	
	// products section
	NSString *productSortByValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"ProductSortby"];
	FieldSpecifier *productSortingByProductIdField = [FieldSpecifier checkFieldWithKey:@"sortby.productId" title:@"Product ID" 
																			defaultValue:[productSortByValue isEqualToString:@"productId"]];
	FieldSpecifier *productSortingByColorField = [FieldSpecifier checkFieldWithKey:@"sortby.color" title:@"Color" 
																		defaultValue:[productSortByValue isEqualToString:@"color"]];
	NSMutableArray *productSortingFields = [NSMutableArray arrayWithObjects:productSortingByProductIdField, productSortingByColorField, nil];


	FieldSectionSpecifier *productSortingSection = [FieldSectionSpecifier sectionWithFields:productSortingFields
																				  title:NSLocalizedString(@"Sort By", nil)
																			description:nil];
	productSortingSection.exclusiveSelection = YES;
	FieldSpecifier *productsSectionField = [FieldSpecifier subsectionFieldWithSection:productSortingSection key:@"sortby"];
	FieldSectionSpecifier *productsSection = [FieldSectionSpecifier sectionWithFields:[NSArray arrayWithObjects:productsSectionField, nil] 
																				  title:NSLocalizedString(@"Products", nil) 
																			description:NSLocalizedString(@"", nil)];
		  
	NSArray *sections = [NSArray arrayWithObjects:generalSection, paymentsSection, productsSection, nil];
	settingsViewController = [[FieldEditorViewController alloc] initWithFieldSections:sections title:NSLocalizedString(@"Settings",nil)];
	settingsViewController.doneButtonTitle = NSLocalizedString(@"Done", nil);
	settingsViewController.showDoneButtonOnLeft = YES;
	settingsViewController.delegate = self;
	settingsViewController.editorIdentifier = kSettingsEditorIdentifier;
	
	settingsNavController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		settingsNavController.modalPresentationStyle = UIModalPresentationFormSheet;
	}
	[self presentViewController:settingsNavController animated:YES completion:nil];
}

- (void)fieldEditor:(FieldEditorViewController *)editor didFinishEditingWithValues:(NSDictionary *)returnValues {
	if ([editor.editorIdentifier isEqualToString:kAddNewAccountEditorIdentifier] || [editor.editorIdentifier isEqualToString:kEditAccountEditorIdentifier]) {
		NSString *username = [returnValues objectForKey:kAccountUsername];
		NSString *password = [returnValues objectForKey:kAccountPassword];
		NSString *appPassword = [returnValues objectForKey:kAccountAppPassword];
		NSString *vendorID = [returnValues objectForKey:kAccountVendorID];
		NSString *title = [returnValues objectForKey:kAccountTitle];
		if ((username.length == 0) && (title.length == 0)) {
			[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Missing Information", nil) message:NSLocalizedString(@"You need to enter at least a username or a description.\n\nAll fields are required if you want to download reports from iTunes Connect, otherwise you can just enter a description.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] show];
			return;
		}
		if (((password.length > 0) && (appPassword.length == 0)) || ((password.length == 0) && (appPassword.length > 0))) {
			[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Missing Information", nil) message:NSLocalizedString(@"You need to enter both your account password and an app-specific password in order to download reports from iTunes Connect.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] show];
			return;
		}
		if ((password.length > 0) && (vendorID.length == 0)) {
			[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Missing Information", nil) message:NSLocalizedString(@"You need to enter a vendor ID. If you don't know your vendor ID, tap \"Auto-Fill Vendor ID\".", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] show];
			return;
		}
		if ([editor.editorIdentifier isEqualToString:kAddNewAccountEditorIdentifier]) {
			ASAccount *account = (ASAccount *)[NSEntityDescription insertNewObjectForEntityForName:@"Account" inManagedObjectContext:self.managedObjectContext];
			account.title = title;
			account.username = username;
			account.vendorID = vendorID;
			account.sortIndex = [NSNumber numberWithLong:time(NULL)];
			account.password = password;
			account.appPassword = appPassword;
		}
		else if ([editor.editorIdentifier isEqualToString:kEditAccountEditorIdentifier]) {
			ASAccount *account = (ASAccount *)editor.context;
			[account deletePassword];
			account.username = username;
			account.title = title;
			account.vendorID = vendorID;
			account.password = password;
			account.appPassword = appPassword;
			
			NSMutableDictionary *productsByID = [NSMutableDictionary dictionary];
			for (Product *product in self.selectedAccount.products) {
				[productsByID setObject:product forKey:product.productID];
			}
			for (NSString *key in [returnValues allKeys]) {
				if ([key hasPrefix:@"product.name."]) {
					NSString *productID = [key substringFromIndex:[@"product.name." length]];
					Product *product = [productsByID objectForKey:productID];
					NSString *newName = [returnValues objectForKey:key];
					if (![[product displayName] isEqualToString:newName]) {
						product.customName = newName;
					}
				} else if ([key hasPrefix:@"product.hidden."]) {
					NSString *productID = [key substringFromIndex:[@"product.hidden." length]];
					Product *product = [productsByID objectForKey:productID];
					product.hidden = [returnValues objectForKey:key];
				}
			}
		}
		[self saveContext];
		if ([editor.editorIdentifier isEqualToString:kAddNewAccountEditorIdentifier]) {
			[editor dismissViewControllerAnimated:YES completion:nil];
		}
		self.selectedAccount = nil;
	} else if ([editor.editorIdentifier isEqualToString:kSettingsEditorIdentifier]) {
		for (NSString *key in [returnValues allKeys]) {
			if ([key hasPrefix:@"currency."]) {
				if ([[returnValues objectForKey:key] boolValue]) {
					[[CurrencyManager sharedManager] setBaseCurrency:[[key componentsSeparatedByString:@"."] lastObject]];
				}
			}
			if ([key hasPrefix:@"sortby."]) {
				if ([[returnValues objectForKey:key] boolValue]) {
					[[NSUserDefaults standardUserDefaults] setObject:[[key componentsSeparatedByString:@"."] lastObject] forKey:@"ProductSortby"];
				}
			}
		}
		[[NSUserDefaults standardUserDefaults] setBool:[[returnValues objectForKey:kSettingDownloadPayments] boolValue] forKey:kSettingDownloadPayments];
		[[NSUserDefaults standardUserDefaults] setBool:[[returnValues objectForKey:kSettingDeleteCookies] boolValue] forKey:kSettingDeleteCookies];
		[self dismissViewControllerAnimated:YES completion:nil];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ASViewSettingsDidChangeNotification object:nil];
	}
	[self reloadAccounts];
}

- (void)fieldEditor:(FieldEditorViewController *)editor pressedButtonWithKey:(NSString *)key {
	if ([key isEqualToString:kPasscodeLockButton]) {
		KKPasscodeSettingsViewController *vc = [[KKPasscodeSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
		vc.delegate = self;
		[settingsNavController pushViewController:vc animated:YES];
	} else if ([key isEqualToString:kUpdateExchangeRatesButton]) {
		[[CurrencyManager sharedManager] forceRefresh];
	} else if ([key isEqualToString:kImportReportsButton]) {
		ASAccount *account = (ASAccount *)editor.context;
		if (account.isDownloadingReports) {
			[[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"AppSales is already importing reports for this account. Please wait until the current import has finished.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] show];
		} else {
			BOOL canStartImport = [ReportImportOperation filesAvailableToImport];
			if (!canStartImport) {
				[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No Files Found", nil) message:NSLocalizedString(@"The Documents directory does not contain any .txt files. Please use iTunes File Sharing to transfer report files to your device.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] show];
			} else {
				UIAlertView *confirmImportAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Begin Import?", nil) 
																			  message:NSLocalizedString(@"Do you want to start importing all report files in the Documents directory into this account?", nil) 
																			 delegate:self 
																	cancelButtonTitle:NSLocalizedString(@"Cancel", nil) 
																	otherButtonTitles:NSLocalizedString(@"Start Import", nil), nil];
				confirmImportAlert.tag = kAlertTagConfirmImport;
				[confirmImportAlert show];
			}
		}
	} else if ([key isEqualToString:kExportReportsButton]) {
		[self doExport];
	} else if ([key hasPrefix:@"product.appstore."]) {
		NSString *productID = [key substringFromIndex:[@"product.appstore." length]];
		NSString *appStoreURLString = [NSString stringWithFormat:@"http://itunes.apple.com/app/id%@", productID];
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:appStoreURLString]];
	} else if ([key hasPrefix:@"product.reload."]) {
		NSString *productID = [key substringFromIndex:[@"product.reload." length]];
		IconManager *iconManager = [IconManager sharedManager];
		[iconManager clearIconForAppID:productID];
	} else if ([key isEqualToString:kDeleteAccountButton]) {
		UIAlertView *confirmDeleteAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Delete Account?", nil) 
																	  message:NSLocalizedString(@"Do you really want to delete this account and all of its data?", nil) 
																	 delegate:self 
															cancelButtonTitle:NSLocalizedString(@"Cancel", nil) 
															otherButtonTitles:NSLocalizedString(@"Delete", nil), nil];
		confirmDeleteAlert.tag = kAlertTagConfirmDelete;
		[confirmDeleteAlert show];
	} else if ([key isEqualToString:@"GenerateAppPasswordButton"]) {
		NSURL *manageAppleIDURL = [NSURL URLWithString:@"https://appleid.apple.com/account/manage/security"];
		UIApplication *application = [UIApplication sharedApplication];
		if ([application canOpenURL:manageAppleIDURL]) {
			[application openURL:manageAppleIDURL];
		}
	} else if ([key isEqualToString:@"SelectVendorIDButton"]) {
		FieldEditorViewController *vc = nil;
		if (self.presentedViewController) {
			UINavigationController *nav = (UINavigationController *)self.presentedViewController;
			vc = (FieldEditorViewController *)[[nav viewControllers] objectAtIndex:0];
		} else {
			vc = (FieldEditorViewController *)[self.navigationController.viewControllers lastObject];
		}
		NSString *username = [vc.values objectForKey:kAccountUsername];
		NSString *password = [vc.values objectForKey:kAccountPassword];
		
		if ((username.length == 0) || (password.length == 0)) {
			[[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"Please enter your username and password first.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] show];
			return;
		}
		[vc dismissKeyboard];
		
		NSDictionary *loginInfo = @{kAccountUsername: username, kAccountPassword: password};
		
		MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:vc.navigationController.view animated:YES];
		hud.labelText = NSLocalizedString(@"Fetching Vendor ID...", nil);
		[self findVendorIDsWithLogin:loginInfo];
	}
}

- (void)doExport {
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
	hud.mode = MBProgressHUDModeDeterminateHorizontalBar;//MBProgressHUDModeDeterminate;
	hud.labelText = NSLocalizedString(@"Exporting", nil);
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), ^{
		NSURL *documentsURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
		NSString *exportFolder = [self folderNameForExportingReportsOfAccount:self.selectedAccount];
		NSURL *exportURL = [documentsURL URLByAppendingPathComponent:exportFolder];
		NSURL *exportedReportsZipFileURL = [exportURL URLByAppendingPathExtension:@"zip"];
		
		[[NSFileManager defaultManager] removeItemAtURL:exportedReportsZipFileURL error:nil];
		[[NSFileManager defaultManager] createDirectoryAtURL:exportURL withIntermediateDirectories:YES attributes:nil error:nil];
		
		NSOperationQueue *reportExportQueue = [[NSOperationQueue alloc] init];
		reportExportQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
		reportExportQueue.qualityOfService = NSQualityOfServiceUserInitiated;
		
		__block NSNumber *exportedReports = @(0);
		__block NSUInteger totalReports = self.selectedAccount.dailyReports.count + self.selectedAccount.weeklyReports.count;
		
		void (^exportBlock)(Report *report) = ^(Report *report) {
			NSString *csv = [report valueForKeyPath:@"originalReport.content"];
			NSString *filename = [report valueForKeyPath:@"originalReport.filename"];
			if ([filename hasSuffix:@".gz"]) {
				filename = [filename substringToIndex:filename.length - 3];
			}
			NSURL *reportURL = [exportURL URLByAppendingPathComponent:filename];
			[csv writeToURL:reportURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
			
			@synchronized(exportedReports) {
				exportedReports = @(exportedReports.unsignedIntegerValue + 1);
				hud.progress = ((CGFloat)exportedReports.unsignedIntegerValue / (CGFloat)totalReports);
			}
		};
		
		[reportExportQueue addOperationWithBlock:^{
			for (Report *dailyReport in self.selectedAccount.dailyReports) {
				[reportExportQueue addOperationWithBlock:^{
					exportBlock(dailyReport);
				}];
			}
		}];
		
		[reportExportQueue addOperationWithBlock:^{
			for (Report *weeklyReport in self.selectedAccount.weeklyReports) {
				[reportExportQueue addOperationWithBlock:^{
					exportBlock(weeklyReport);
				}];
			}
		}];
		
		[reportExportQueue waitUntilAllOperationsAreFinished];
		
		hud.mode = MBProgressHUDModeIndeterminate;
		hud.labelText = NSLocalizedString(@"Compressing", nil);
		
		ZIPArchive *zipArchive = [[ZIPArchive alloc] initWithFileURL:exportedReportsZipFileURL];
		[zipArchive addDirectoryToArchive:exportURL];
		[zipArchive writeToFile];
		
		[[NSFileManager defaultManager] removeItemAtURL:exportURL error:nil];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
			
			self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:exportedReportsZipFileURL];
			self.documentInteractionController.delegate = self;
			[self.documentInteractionController presentOptionsMenuFromRect:self.navigationController.view.bounds inView:self.navigationController.view animated:YES];
		});
	});
}

- (NSString *)folderNameForExportingReportsOfAccount:(ASAccount *)account {
	NSString *folder = account.title;
	if (!folder || folder.length == 0) {
		folder = account.username;
	}
	if (!folder || folder.length == 0) {
		folder = @"Untitled Account";
	}
	folder = [folder stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
	folder = [folder stringByReplacingOccurrencesOfString:@":" withString:@"-"];
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"YYYY-MM-dd"];
	NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
	folder = [folder stringByAppendingFormat:@" %@", dateString];
	return folder;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag == kAlertTagConfirmImport) {
		if (buttonIndex != [alertView cancelButtonIndex]) {
			[[ReportDownloadCoordinator sharedReportDownloadCoordinator] importReportsIntoAccount:self.selectedAccount];
			[self.navigationController popViewControllerAnimated:YES];
		}
	} else if (alertView.tag == kAlertTagConfirmDelete) {
		if (buttonIndex != [alertView cancelButtonIndex]) {
			MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
			[hud setLabelText:NSLocalizedString(@"Deleting Account...", nil)];
			
			ASAccount *account = self.selectedAccount;
			[self performSelector:@selector(deleteAccount:) withObject:account afterDelay:0.1];
		}
	}
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
	self.documentInteractionController = nil;
}

- (void)fieldEditorDidCancel:(FieldEditorViewController *)editor {
	[editor dismissViewControllerAnimated:YES completion:nil];
}

- (void)didSettingsChanged:(KKPasscodeSettingsViewController *)viewController {
  
  if ([[KKPasscodeLock sharedLock] isPasscodeRequired]) {
	passcodeLockField.defaultValue = @"On";
  } else {
	passcodeLockField.defaultValue = @"Off";
  }
  
  [settingsViewController.tableView reloadData];
}

- (void)iconCleared:(NSNotification *)notification {
	NSString *productID = [[notification userInfo] objectForKey:kIconManagerClearedIconNotificationAppID];
	if (productID) {
		// Reload icon.
		[[IconManager sharedManager] iconForAppID:productID];
	}
}

#pragma mark -

- (void)saveContext {
	NSError *error = nil;
	if (![[self managedObjectContext] save:&error]) { 
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
	}
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

@end
