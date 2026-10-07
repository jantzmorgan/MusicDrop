#import "MDImportViewController.h"
#import "MDImportCoordinator.h"
#import "MDTrackMetadata.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MDImportViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong, nullable) NSURL *audioURL;
@property (nonatomic, strong, nullable) MDTrackMetadata *metadata;
@property (nonatomic, strong) UILabel *headlineLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIButton *chooseButton;
@property (nonatomic, strong) UIButton *importButton;
@end

@implementation MDImportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"MusicDrop";

    UIBarButtonItem *close = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                                          target:self
                                                                          action:@selector(closeTapped)];
    self.navigationItem.rightBarButtonItem = close;

    UILabel *badge = [UILabel new];
    badge.text = @"MUSICDROP • DEVICE TEST";
    badge.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    badge.textColor = UIColor.systemPinkColor;

    self.headlineLabel = [UILabel new];
    self.headlineLabel.text = @"Choose a song";
    self.headlineLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    self.headlineLabel.numberOfLines = 0;

    self.detailLabel = [UILabel new];
    self.detailLabel.text = @"Select an MP3, M4A, or AAC file from Files. MusicDrop will read its metadata and show it here.";
    self.detailLabel.font = [UIFont systemFontOfSize:16];
    self.detailLabel.textColor = UIColor.secondaryLabelColor;
    self.detailLabel.numberOfLines = 0;

    self.chooseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.chooseButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [self.chooseButton setTitle:@"Choose Audio File" forState:UIControlStateNormal];
    [self.chooseButton addTarget:self action:@selector(chooseTapped) forControlEvents:UIControlEventTouchUpInside];

    self.importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.importButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [self.importButton setTitle:@"Import to Music (Test)" forState:UIControlStateNormal];
    self.importButton.enabled = NO;
    [self.importButton addTarget:self action:@selector(importTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        badge, self.headlineLabel, self.detailLabel, self.chooseButton, self.importButton
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:32]
    ]];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)chooseTapped {
    NSArray<UTType *> *types = @[UTTypeAudio];
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    NSError *error = nil;
    MDTrackMetadata *metadata = [[MDImportCoordinator sharedCoordinator] metadataForAudioURL:url error:&error];

    if (!metadata) {
        self.audioURL = nil;
        self.metadata = nil;
        self.headlineLabel.text = @"Couldn't read that file";
        self.detailLabel.text = error.localizedDescription ?: @"Choose an MP3, M4A, or AAC file.";
        self.importButton.enabled = NO;
        return;
    }

    self.audioURL = url;
    self.metadata = metadata;
    self.headlineLabel.text = metadata.title;
    self.detailLabel.text = [NSString stringWithFormat:
        @"Artist: %@\nAlbum: %@\nFile: %@\n\n✓ MusicDrop successfully read this audio file.",
        metadata.artist.length ? metadata.artist : @"Unknown Artist",
        metadata.album.length ? metadata.album : @"Unknown Album",
        url.lastPathComponent];
    self.importButton.enabled = YES;
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
}

- (void)importTapped {
    if (!self.audioURL || !self.metadata) return;

    self.importButton.enabled = NO;
    [self.importButton setTitle:@"Testing Import…" forState:UIControlStateNormal];

    [[MDImportCoordinator sharedCoordinator] importAudioAtURL:self.audioURL
                                                    metadata:self.metadata
                                                  completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.importButton.enabled = YES;
            [self.importButton setTitle:@"Import to Music (Test)" forState:UIControlStateNormal];

            UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:success ? @"Imported" : @"Metadata Test Passed"
                                                    message:success
                                                        ? @"The song was added to your Music library."
                                                        : [NSString stringWithFormat:
                                                           @"MusicDrop loaded the file correctly.\n\nNext milestone: connect native Music-library insertion.\n\nBackend response: %@",
                                                           error.localizedDescription ?: @"Not connected yet."]
                                             preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}
@end
