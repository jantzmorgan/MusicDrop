#import "MDImportViewController.h"
#import "MDImportCoordinator.h"
#import "MDTrackMetadata.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MDImportViewController () <UIDocumentPickerDelegate, UITextFieldDelegate>
@property (nonatomic, strong, nullable) NSURL *audioURL;
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
@end

@implementation MDImportViewController

- (UITextField *)field:(NSString *)placeholder {
    UITextField *field = [UITextField new];
    field.placeholder = placeholder;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.delegate = self;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.heightAnchor.active = YES;
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

    for (UIView *view in @[self.artworkView, self.statusLabel, self.fileLabel, choose,
                           self.titleField, self.artistField, self.albumField, self.albumArtistField,
                           self.genreField, self.yearField, self.trackField, self.importButton]) {
        [self.stack addArrangedSubview:view];
    }

    [self.artworkView.heightAnchor constraintEqualToAnchor:self.artworkView.widthAnchor].active = YES;
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

- (void)closeTapped { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)chooseTapped {
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeAudio] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    NSError *error = nil;
    MDTrackMetadata *metadata = [[MDImportCoordinator sharedCoordinator] metadataForAudioURL:url error:&error];
    if (!metadata) {
        self.statusLabel.text = error.localizedDescription ?: @"Could not read this file.";
        self.importButton.enabled = NO;
        return;
    }

    self.audioURL = url;
    self.metadata = metadata;
    self.titleField.text = metadata.title;
    self.artistField.text = metadata.artist;
    self.albumField.text = metadata.album;
    self.albumArtistField.text = metadata.albumArtist;
    self.genreField.text = metadata.genre;
    self.yearField.text = metadata.year.stringValue ?: @"";
    self.trackField.text = metadata.trackNumber.stringValue ?: @"";
    if (metadata.artwork) self.artworkView.image = metadata.artwork;

    NSInteger seconds = (NSInteger)llround(metadata.duration);
    self.fileLabel.text = [NSString stringWithFormat:@"%@ • %ld:%02ld • %@",
                           url.pathExtension.uppercaseString,
                           (long)(seconds / 60), (long)(seconds % 60),
                           url.lastPathComponent];
    self.statusLabel.text = @"Ready to review. Edit anything below before importing.";
    self.importButton.enabled = YES;
}

- (void)syncFieldsToMetadata {
    self.metadata.title = self.titleField.text.length ? self.titleField.text : @"Unknown Title";
    self.metadata.artist = self.artistField.text.length ? self.artistField.text : @"Unknown Artist";
    self.metadata.album = self.albumField.text.length ? self.albumField.text : @"Unknown Album";
    self.metadata.albumArtist = self.albumArtistField.text ?: @"";
    self.metadata.genre = self.genreField.text ?: @"";
    self.metadata.year = self.yearField.text.length ? @([self.yearField.text integerValue]) : nil;
    self.metadata.trackNumber = self.trackField.text.length ? @([self.trackField.text integerValue]) : nil;
}

- (void)importTapped {
    if (!self.audioURL || !self.metadata) return;
    [self syncFieldsToMetadata];
    self.importButton.enabled = NO;
    self.statusLabel.text = @"Attempting native Music import…";

    [[MDImportCoordinator sharedCoordinator] importAudioAtURL:self.audioURL metadata:self.metadata completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.importButton.enabled = YES;
            self.statusLabel.text = success ? @"Imported successfully." : @"Import backend not connected yet.";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:success ? @"Imported" : @"MusicDrop"
                                                                           message:success ? @"The song is now in Music." : error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}
@end
