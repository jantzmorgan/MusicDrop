#import "MDImportViewController.h"
#import "MDImportCoordinator.h"
#import "MDTrackMetadata.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MDImportViewController () <UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate>
@property (nonatomic, strong, nullable) NSURL *audioURL;
@property (nonatomic, strong) NSArray<NSURL *> *batchURLs;
@property (nonatomic) NSUInteger batchIndex;
@property (nonatomic) NSUInteger batchSuccessCount;
@property (nonatomic) NSUInteger batchFailureCount;
@property (nonatomic) BOOL importingBatch;
@property (nonatomic, strong) NSMutableArray<MDTrackMetadata *> *batchMetadata;
@property (nonatomic) NSUInteger selectedBatchIndex;
@property (nonatomic, strong) UISegmentedControl *batchSelector;
@property (nonatomic, strong) UIButton *applyCoverButton;
@property (nonatomic, strong, nullable) MDTrackMetadata *metadata;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIImageView *artworkView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *fileLabel;
@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextField *artistField;
@property (nonatomic, strong) UITextField *albumField;
@property (nonatomic, strong) UITextField *albumArtistField;
@property (nonatomic, strong) UITextField *genreField;
@property (nonatomic, strong) UITextField *yearField;
@property (nonatomic, strong) UITextField *trackField;
@property (nonatomic, strong) UIButton *importButton;
@property (nonatomic, strong) UIButton *artworkButton;
@property (nonatomic) BOOL selectingArtwork;
@property (nonatomic, weak, nullable) UITextField *activeField;
@end

@implementation MDImportViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.pendingAudioURL && !self.audioURL) {
        NSURL *url = self.pendingAudioURL;
        self.pendingAudioURL = nil;
        [self loadAudioURL:url];
    }
}

- (UITextField *)field:(NSString *)placeholder {
    UITextField *field = [UITextField new];
    field.placeholder = placeholder;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.delegate = self;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.returnKeyType = UIReturnKeyDone;

    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)];
    toolbar.items = @[flex, done];
    field.inputAccessoryView = toolbar;
    [field.heightAnchor constraintEqualToConstant:44].active = YES;
    return field;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"MusicDrop";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(closeTapped)];

    self.scrollView = [UIScrollView new];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.scrollView];

    self.stack = [UIStackView new];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 12;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stack];

    self.artworkView = [UIImageView new];
    self.artworkView.contentMode = UIViewContentModeScaleAspectFill;
    self.artworkView.clipsToBounds = YES;
    self.artworkView.layer.cornerRadius = 18;
    self.artworkView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.artworkView.image = [UIImage systemImageNamed:@"music.note"];
    self.artworkView.tintColor = UIColor.secondaryLabelColor;

    self.artworkButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.artworkButton setTitle:@"Change Cover Artwork" forState:UIControlStateNormal];
    [self.artworkButton addTarget:self action:@selector(chooseArtworkTapped) forControlEvents:UIControlEventTouchUpInside];

    self.statusLabel = [UILabel new];
    self.statusLabel.text = @"Choose a local song to begin.";
    self.statusLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.statusLabel.numberOfLines = 0;

    self.fileLabel = [UILabel new];
    self.fileLabel.text = @"MP3 • M4A • AAC";
    self.fileLabel.textColor = UIColor.secondaryLabelColor;
    self.fileLabel.font = [UIFont systemFontOfSize:13];
    self.fileLabel.numberOfLines = 0;

    UIButton *choose = [UIButton buttonWithType:UIButtonTypeSystem];
    [choose setTitle:@"Choose Audio File" forState:UIControlStateNormal];
    choose.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [choose addTarget:self action:@selector(chooseTapped) forControlEvents:UIControlEventTouchUpInside];

    self.titleField = [self field:@"Title"];
    self.artistField = [self field:@"Artist"];
    self.albumField = [self field:@"Album"];
    self.albumArtistField = [self field:@"Album Artist"];
    self.genreField = [self field:@"Genre"];
    self.yearField = [self field:@"Year"];
    self.yearField.keyboardType = UIKeyboardTypeNumberPad;
    self.trackField = [self field:@"Track Number"];
    self.trackField.keyboardType = UIKeyboardTypeNumberPad;

    self.importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.importButton setTitle:@"Import to Music" forState:UIControlStateNormal];
    self.importButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    self.importButton.enabled = NO;
    [self.importButton addTarget:self action:@selector(importTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *coverRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.artworkView, self.artworkButton]];
    coverRow.axis = UILayoutConstraintAxisHorizontal;
    coverRow.alignment = UIStackViewAlignmentCenter;
    coverRow.spacing = 16;
    self.artworkButton.titleLabel.numberOfLines = 2;
    self.artworkButton.titleLabel.textAlignment = NSTextAlignmentLeft;
    [self.artworkView.widthAnchor constraintEqualToConstant:110].active = YES;
    [self.artworkView.heightAnchor constraintEqualToConstant:110].active = YES;
    [self.artworkButton setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    self.batchSelector = [[UISegmentedControl alloc] initWithItems:@[]];
    [self.batchSelector addTarget:self action:@selector(batchSelectionChanged:) forControlEvents:UIControlEventValueChanged];
    self.batchSelector.hidden = YES;
    self.applyCoverButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.applyCoverButton setTitle:@"Apply Cover to All Songs" forState:UIControlStateNormal];
    [self.applyCoverButton addTarget:self action:@selector(applyCoverToAll) forControlEvents:UIControlEventTouchUpInside];
    self.applyCoverButton.hidden = YES;

    for (UIView *view in @[coverRow, self.applyCoverButton, self.statusLabel, self.fileLabel, choose, self.batchSelector,
                           self.titleField, self.artistField, self.albumField, self.albumArtistField,
                           self.genreField, self.yearField, self.trackField, self.importButton]) {
        [self.stack addArrangedSubview:view];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:24],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-24],
        [self.stack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:20],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-30],
        [self.stack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-48]
    ]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.activeField = textField;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        CGRect rect = [textField convertRect:textField.bounds toView:self.scrollView];
        [self.scrollView scrollRectToVisible:CGRectInset(rect, 0, -24) animated:YES];
    });
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (self.activeField == textField) self.activeField = nil;
}

- (void)keyboardWillChange:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    CGRect keyboardScreen = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboard = [self.view convertRect:keyboardScreen fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboard));

    UIEdgeInsets inset = self.scrollView.contentInset;
    inset.bottom = overlap + 16.0;
    self.scrollView.contentInset = inset;
    self.scrollView.scrollIndicatorInsets = inset;

    if (self.activeField) {
        CGRect rect = [self.activeField convertRect:self.activeField.bounds toView:self.scrollView];
        [self.scrollView scrollRectToVisible:CGRectInset(rect, 0, -24) animated:YES];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets inset = self.scrollView.contentInset;
    inset.bottom = 0;
    self.scrollView.contentInset = inset;
    self.scrollView.scrollIndicatorInsets = inset;
}

- (void)closeTapped {
    [self dismissKeyboard];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)chooseArtworkTapped {
    if (!self.metadata) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Cover Artwork" message:@"Choose any image from Photos or Files." preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Files" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.selectingArtwork = YES;
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeImage] asCopy:YES];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Photos" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self chooseArtworkFromPhotos]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.artworkButton;
    sheet.popoverPresentationController.sourceRect = self.artworkButton.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)chooseArtworkFromPhotos {
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.allowsEditing = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    if (image && self.metadata) {
        self.metadata.artwork = image;
        self.artworkView.image = image;
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)chooseTapped {
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeAudio] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)loadAudioURL:(NSURL *)url {
    if (!url) return;

    NSError *error = nil;
    MDTrackMetadata *metadata = [[MDImportCoordinator sharedCoordinator] metadataForAudioURL:url error:&error];
    if (!metadata) {
        self.statusLabel.text = error.localizedDescription ?: @"Could not read this file.";
        self.importButton.enabled = NO;
        return;
    }

    [self displayAudioURL:url metadata:metadata];
}

- (void)displayAudioURL:(NSURL *)url metadata:(MDTrackMetadata *)metadata {
    self.audioURL = url;
    self.metadata = metadata;
    self.titleField.text = metadata.title;
    self.artistField.text = metadata.artist;
    self.albumField.text = metadata.album;
    self.albumArtistField.text = metadata.albumArtist;
    self.genreField.text = metadata.genre;
    self.yearField.text = metadata.year.stringValue ?: @"";
    self.trackField.text = metadata.trackNumber.stringValue ?: @"";
    self.artworkView.image = metadata.artwork ?: [UIImage systemImageNamed:@"music.note"];

    NSInteger seconds = (NSInteger)llround(metadata.duration);
    self.fileLabel.text = [NSString stringWithFormat:@"%@ • %ld:%02ld • %@",
                           url.pathExtension.uppercaseString,
                           (long)(seconds / 60), (long)(seconds % 60),
                           url.lastPathComponent];
    self.statusLabel.text = @"Review metadata before importing. Cover artwork is a preview until native artwork transfer is verified.";
    self.importButton.enabled = YES;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (self.selectingArtwork) {
        self.selectingArtwork = NO;
        NSData *data = [NSData dataWithContentsOfURL:urls.firstObject];
        UIImage *image = data.length <= 20 * 1024 * 1024 ? [UIImage imageWithData:data] : nil;
        if (image && self.metadata) { self.metadata.artwork = image; self.artworkView.image = image; }
        else self.statusLabel.text = @"Could not open that image (maximum 20 MB).";
        return;
    }
    NSMutableArray<NSURL *> *valid = [NSMutableArray array];
    NSMutableArray<MDTrackMetadata *> *tags = [NSMutableArray array];
    for (NSURL *url in urls) {
        if (![[MDImportCoordinator sharedCoordinator] isSupportedAudioURL:url]) continue;
        MDTrackMetadata *tag = [[MDImportCoordinator sharedCoordinator] metadataForAudioURL:url error:nil];
        if (tag) { [valid addObject:url]; [tags addObject:tag]; }
    }
    if (!valid.count) { self.statusLabel.text = @"No readable audio files selected."; return; }
    self.batchURLs = valid.copy;
    self.batchMetadata = tags;
    self.selectedBatchIndex = 0;
    [self.batchSelector removeAllSegments];
    for (NSUInteger i = 0; i < valid.count; i++) {
        NSString *name = valid[i].URLByDeletingPathExtension.lastPathComponent;
        [self.batchSelector insertSegmentWithTitle:name atIndex:i animated:NO];
    }
    self.batchSelector.hidden = valid.count <= 1;
    self.applyCoverButton.hidden = valid.count <= 1;
    self.batchSelector.selectedSegmentIndex = 0;
    [self displayAudioURL:valid.firstObject metadata:tags.firstObject];
    [self.importButton setTitle:valid.count > 1 ? [NSString stringWithFormat:@"Import All (%lu)", (unsigned long)valid.count] : @"Import to Music" forState:UIControlStateNormal];
    self.statusLabel.text = valid.count > 1 ? @"Select each song to edit its own metadata and artwork." : @"Ready to import.";
}

- (void)batchSelectionChanged:(UISegmentedControl *)sender {
    if (self.importingBatch || sender.selectedSegmentIndex < 0) return;
    [self syncFieldsToMetadata];
    NSUInteger index = (NSUInteger)sender.selectedSegmentIndex;
    if (index >= self.batchURLs.count) return;
    self.selectedBatchIndex = index;
    [self displayAudioURL:self.batchURLs[index] metadata:self.batchMetadata[index]];
}

- (void)applyCoverToAll {
    [self syncFieldsToMetadata];
    if (!self.metadata.artwork || self.batchMetadata.count < 2) {
        self.statusLabel.text = @"Choose a cover image first.";
        return;
    }
    for (MDTrackMetadata *track in self.batchMetadata) track.artwork = self.metadata.artwork;
    self.statusLabel.text = @"Cover applied to all selected songs.";
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller { self.selectingArtwork = NO; }

- (void)syncFieldsToMetadata {
    self.metadata.title = self.titleField.text.length ? self.titleField.text : @"Unknown Title";
    self.metadata.artist = self.artistField.text.length ? self.artistField.text : @"Unknown Artist";
    self.metadata.album = self.albumField.text.length ? self.albumField.text : @"Unknown Album";
    self.metadata.albumArtist = self.albumArtistField.text ?: @"";
    self.metadata.genre = self.genreField.text ?: @"";
    NSInteger year = self.yearField.text.integerValue;
    self.metadata.year = year > 0 && year <= 9999 ? @(year) : nil;
    NSInteger track = self.trackField.text.integerValue;
    self.metadata.trackNumber = track > 0 ? @(track) : nil;
}

- (void)importNextBatchItem {
    if (self.batchIndex >= self.batchURLs.count) {
        self.importingBatch = NO;
        self.importButton.enabled = YES;
        [self.importButton setTitle:@"Import to Music" forState:UIControlStateNormal];
        self.statusLabel.text = [NSString stringWithFormat:@"Accepted into queue: %lu of %lu. Rejected: %lu. Check Music Library for completed downloads.", (unsigned long)self.batchSuccessCount, (unsigned long)self.batchURLs.count, (unsigned long)self.batchFailureCount];
        self.batchURLs = nil;
        return;
    }
    NSUInteger index = self.batchIndex++;
    NSURL *url = self.batchURLs[index];
    self.importButton.enabled = NO;
    self.statusLabel.text = [NSString stringWithFormat:@"Queueing song %lu of %lu…", (unsigned long)(index + 1), (unsigned long)self.batchURLs.count];
    NSError *error = nil;
    MDTrackMetadata *track = index < self.batchMetadata.count ? self.batchMetadata[index] : nil;
    if (!track) {
        self.batchFailureCount++;
        dispatch_async(dispatch_get_main_queue(), ^{ [self importNextBatchItem]; });
        return;
    }
    [[MDImportCoordinator sharedCoordinator] importAudioAtURL:url metadata:track completion:^(BOOL accepted, NSError *importError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (accepted) self.batchSuccessCount++;
            else self.batchFailureCount++;
            [self importNextBatchItem];
        });
    }];
}

- (void)importTapped {
    if (!self.audioURL || !self.metadata || self.importingBatch) return;
    [self syncFieldsToMetadata];
    if (self.batchURLs.count > 1) {
        self.importingBatch = YES;
        self.batchIndex = 0;
        self.batchSuccessCount = 0;
        self.batchFailureCount = 0;
        [self importNextBatchItem];
        return;
    }
    self.importButton.enabled = NO;
    self.statusLabel.text = @"Attempting native Music import…";

    [[MDImportCoordinator sharedCoordinator] importAudioAtURL:self.audioURL metadata:self.metadata completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.importButton.enabled = YES;
            self.statusLabel.text = success ? @"Apple Music accepted the native import. Check Library." : @"Import failed.";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:success ? @"Imported" : @"MusicDrop"
                                                                           message:success ? @"The song is now in Music." : error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}
@end
