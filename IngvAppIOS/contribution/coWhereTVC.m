//
//  coWhereTVC.m
//  Project
//
//  Created by Adriano Di Luzio on 22/01/14.
//  Copyright (c) 2014 Swipe Stack Ltd. All rights reserved.
//

#import "coWhereTVC.h"
#import "coIndirizzoTVC.h"
#import "coWhereLocation.h"
#import <CoreLocation/CoreLocation.h>

typedef enum tipoIndirizzo {
    regione = 1,
    provincia,
    comuni,
    frazione
} tipoIndirizzo;

@interface coWhereTVC () <coIndirizzoTVCDelegate, CLLocationManagerDelegate, UIAlertViewDelegate>
@property (weak, nonatomic) IBOutlet UISwitch *currentPositionSwitch;
@property (weak, nonatomic) IBOutlet UITextField *viaTextField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *nextBarButtonItem;
@property tipoIndirizzo tipoIndirizzo;

@property (weak, nonatomic) IBOutlet UITableViewCell *regioneCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *provinciaCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *comuneCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *frazioneCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *viaCell;

@property (strong, nonatomic) coWhereLocation *location;
@property (strong, nonatomic) CLLocationManager* locationManager;
@property (strong, nonatomic) NSError* locationError;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *locationActivityIndicator;

@property (strong, nonatomic) NSDictionary *region;
@property (strong, nonatomic) NSDictionary *provincia;
@property (strong, nonatomic) NSDictionary *comune;
@property (strong, nonatomic) NSDictionary *frazione;
@property (strong, nonatomic) NSString *via;
@end

@implementation coWhereTVC

# pragma mark - Setters and getters
- (coWhereLocation *) location {
    if (self.delegate.questionario.where == Nil) {
        self.delegate.questionario.where = [[coWhereLocation alloc] init];
    }
    
    return self.delegate.questionario.where;
}

- (CLLocationManager *) locationManager {
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
        _locationManager.distanceFilter = 100;
    }
    return _locationManager;
}

- (void) setRegion:(NSDictionary *)region {
    self.location.regione = region;
    self.provincia = nil;
    
    [self reloadTableView];
}

- (NSDictionary *) region {
    return self.location.regione;
}

- (void) setProvincia:(NSDictionary *)provincia {
    self.location.provincia = provincia;
    self.comune = nil;
    
    [self reloadTableView];
}

- (NSDictionary *) provincia {
    return self.location.provincia;
}

- (void) setComune:(NSDictionary *)comune {
    self.location.comune = comune;
    
    self.frazione = nil;
    self.viaTextField.text = nil;
    
    [self reloadTableView];
}

- (NSDictionary *) comune {
    return self.location.comune;
}

- (void) setFrazione:(NSDictionary *)frazione {
    self.location.frazione = frazione;
    
    [self reloadTableView];
}

- (NSDictionary *) frazione {
    return self.location.frazione;
}

- (void) setVia:(NSString *)via {
    self.location.via = via;
    
    [self reloadTableView];
}

- (NSString *) via {
    return self.location.via;
}

# pragma mark - Location methods
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    //    Take the last updated location, and put it in the location object.
    self.location.coordinate = [[locations lastObject] coordinate];
    self.nextBarButtonItem.enabled = YES;
    [self.locationActivityIndicator stopAnimating];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    self.locationError = error;
}

# pragma mark - coIndirizzoTVC Delegate Methods
- (void)didFinishSelectingAddress:(NSDictionary *)dataDictionary {
    if (self.tipoIndirizzo == regione) {
        self.region = dataDictionary;
    } else if (self.tipoIndirizzo == provincia) {
        self.provincia = dataDictionary;
    } else if (self.tipoIndirizzo == comuni) {
        self.comune = dataDictionary;
    } else if (self.tipoIndirizzo == frazione) {
        self.frazione = dataDictionary;
    }
}

# pragma mark - IBActions
- (IBAction)currestPositionSwitchDidChanged:(UISwitch *)sender {
    if ([sender isOn]) {
        [self.locationManager startUpdatingLocation];
        [self.locationActivityIndicator startAnimating];
        
        self.region = nil;
    } else {
        [self.locationActivityIndicator stopAnimating];
        self.locationManager.delegate = nil;
        [self.locationManager stopUpdatingLocation];
        self.nextBarButtonItem.enabled = NO;

        self.locationManager = nil;
        self.location = nil;
    }
    
    [self reloadTableView];
}

- (IBAction)didEndOnExitEnteringDetail:(UITextField *)sender {
    // Quando l'utente preme "Fatto" sulla tastiera, può andare avanti.
    if ([sender isEqual:self.viaTextField]) {
        self.via = sender.text;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([self.currentPositionSwitch isOn]) {
        return 1;
    } else {
        return 2;
    }
}

- (void) reloadTableView {
    if (!self.currentPositionSwitch.isOn) {
        self.nextBarButtonItem.enabled = NO;

        self.regioneCell.detailTextLabel.text = [[self.region allValues] firstObject];
        
        if (self.region != nil) {
            self.provinciaCell.hidden = NO;
        } else {
            self.provinciaCell.hidden = YES;
        }
        
        self.provinciaCell.detailTextLabel.text = [[self.provincia allValues] firstObject];
        
        if (self.provincia != nil) {
            self.comuneCell.hidden = NO;
        } else {
            self.comuneCell.hidden = YES;
        }
        
        self.comuneCell.detailTextLabel.text = [[self.comune allValues] firstObject];
        
        if (self.comune != nil) {
            self.nextBarButtonItem.enabled = YES;
            self.frazioneCell.hidden = NO;
            self.viaCell.hidden = NO;
        } else {
            self.frazioneCell.hidden = YES;
            self.viaCell.hidden = YES;
        }
        
        self.frazioneCell.detailTextLabel.text = [[self.frazione allValues] firstObject];
        self.viaTextField.text = self.via;
    }
    
    [self.tableView reloadData];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

    if ([segue.destinationViewController isKindOfClass:[coQuestionTVC class]]) {
        coQuestionTVC* qtvc = (coQuestionTVC *) [segue destinationViewController];
        qtvc.delegate = self.delegate;
    }
    
    if ([segue.identifier isEqualToString:@"coRegioneSegue"]) {
        UINavigationController *nc = segue.destinationViewController;
        coIndirizzoTVC *dvc = (coIndirizzoTVC *)[nc topViewController];
        [dvc setTitle:@"Regione"];
        
        dvc.whereDelegate = self;
        self.tipoIndirizzo = regione;
        [dvc loadRegions];
        
    } else if ([segue.identifier isEqualToString:@"coProvinciaSegue"]) {
        UINavigationController *nc = segue.destinationViewController;
        coIndirizzoTVC *dvc = (coIndirizzoTVC *)[nc topViewController];
        [dvc setTitle:@"Provincia"];
        
        dvc.whereDelegate = self;
        self.tipoIndirizzo = provincia;
        [dvc loadProvince:[[self.region allKeys] firstObject]];
        
    } else if ([segue.identifier isEqualToString:@"coComuneSegue"]) {
        UINavigationController *nc = segue.destinationViewController;
        coIndirizzoTVC *dvc = (coIndirizzoTVC *)[nc topViewController];
        [dvc setTitle:@"Comune"];
        
        dvc.whereDelegate = self;
        self.tipoIndirizzo = comuni;
        [dvc loadComuni:[[self.provincia allKeys] firstObject]];
        
    } else if ([segue.identifier isEqualToString:@"coFrazioneSegue"]) {
        UINavigationController *nc = segue.destinationViewController;
        coIndirizzoTVC *dvc = (coIndirizzoTVC *)[nc topViewController];
        [dvc setTitle:@"Frazione"];
        
        dvc.whereDelegate = self;
        self.tipoIndirizzo = frazione;
        [dvc loadFrazioni:[[self.comune allKeys] firstObject] withRegionCode:[[self.region allKeys] firstObject]];
    }
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
        self.currentPositionSwitch.enabled = NO;
    }
    ;
    self.locationManager.delegate = nil;
    [self.locationManager stopUpdatingLocation];
    self.nextBarButtonItem.enabled = NO;
    
    self.locationManager = nil;
    self.location = nil;
    
    [self reloadTableView];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.locationManager stopUpdatingLocation];
}

@end
