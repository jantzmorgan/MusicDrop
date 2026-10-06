#import "MDImportViewController.h"
#import "MDImportCoordinator.h"
#import "MDTrackMetadata.h"

@interface MDImportViewController ()
@property (nonatomic, strong) NSURL *audioURL;
@property (nonatomic, strong) MDTrackMetadata *metadata;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIButton *importButton;
@end

@implementation MDImportViewController

- (instancetype)initWithAudioURL:(NSURL *)audioURL {
    if ((self = [super init])) {
        _audioURL = audioURL;
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"MusicDrop";

    NSError *error = nil;
    self.metadata = [[MDImportCoordinator sharedCoordinator] metadataForAudioURL:self.audioURL error:&error];

    self.titleLabel = [UILabel new];
    self.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.text = self.metadata.title ?: @"MusicDrop";

    self.detailLabel = [UILabel new];
    self.detailLabel.font = [UIFont systemFontOfSize:15];
    self.detailLabel.textColor = UIColor.secondaryLabelColor;
    self.detailLabel.numberOfLines = 0;
    self.detailLabel.text = error ? error.localizedDescription :
        [NSString stringWithFormat:@"%@\n%@\n\n%@", self.metadata.artist, self.metadata.album, self.audioURL.lastPathComponent];

    self.importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.importButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [self.importButton setTitle:@"Import to Music" forState:UIControlStateNormal];
    self.importButton.enabled = (self.metadata != nil);
    [self.importButton addTarget:self action:@selector(importTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.titleLabel, self.detailLabel, self.importButton]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:32]
    ]];
}

- (void)importTapped {
    self.importButton.enabled = NO;
    [self.importButton setTitle:@"Importing…" forState:UIControlStateNormal];

    [[MDImportCoordinator sharedCoordinator] importAudioAtURL:self.audioURL metadata:self.metadata completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.importButton.enabled = YES;
            [self.importButton setTitle:@"Import to Music" forState:UIControlStateNormal];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:success ? @"Imported" : @"MusicDrop Test"
                                                                           message:success ? @"The song was added to your Music library." : error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}
@end
