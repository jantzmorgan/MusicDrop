#import "MDHubViewController.h"
#import "MDImportViewController.h"
#import "MDMediaConverter.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MDHubViewController () <UIDocumentPickerDelegate>
@property (nonatomic) BOOL choosingForConversion;
@end

@implementation MDHubViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"MusicDrop";
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 2 : 1; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Add Music" : @"About";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MusicDropCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"MusicDropCell"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"Import Audio";
        cell.detailTextLabel.text = @"MP3, M4A, or AAC from Files";
        cell.imageView.image = [UIImage systemImageNamed:@"square.and.arrow.down"];
    } else if (indexPath.section == 0) {
        cell.textLabel.text = @"Convert Media";
        cell.detailTextLabel.text = @"Extract audio from a local media file";
        cell.imageView.image = [UIImage systemImageNamed:@"waveform"];
    } else {
        cell.textLabel.text = @"MusicDrop";
        cell.detailTextLabel.text = @"Your music. Your library.";
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.imageView.image = [UIImage systemImageNamed:@"music.note"];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 0) return;

    if (indexPath.row == 0) {
        MDImportViewController *vc = [MDImportViewController new];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    self.choosingForConversion = YES;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeMovie, UTTypeAudio] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url || !self.choosingForConversion) return;
    self.choosingForConversion = NO;

    UIAlertController *working = [UIAlertController alertControllerWithTitle:@"Converting…" message:@"MusicDrop is extracting the audio." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:working animated:YES completion:^{
        [MDMediaConverter convertMediaAtURL:url completion:^(NSURL *outputURL, NSError *error) {
            [working dismissViewControllerAnimated:YES completion:^{
                if (error || !outputURL) {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Conversion Failed" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                    return;
                }

                MDImportViewController *vc = [MDImportViewController new];
                vc.pendingAudioURL = outputURL;
                [self.navigationController pushViewController:vc animated:YES];
            }];
        }];
    }];
}
@end
