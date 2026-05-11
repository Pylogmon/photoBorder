import { webview } from '@kit.ArkWeb';
import { window } from '@kit.ArkUI';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const DEFAULT_STATUS_BAR_COLOR = '#151719';
const TRANSPARENT_SYSTEM_BAR_COLOR = '#00000000';

type ThemeColorChange = (color: string) => void;
type ToastMessage = (message: string) => void;

let onThemeColorChange: ThemeColorChange = (_color: string): void => {};

class SystemBarBridge {
  setThemeColor(color: string): void {
    onThemeColorChange(color);
  }
}

class AlbumBridge {
  private context: common.UIAbilityContext;
  private showToast: ToastMessage;
  private atManager = abilityAccessCtrl.createAtManager();

  constructor(context: common.UIAbilityContext, showToast: ToastMessage) {
    this.context = context;
    this.showToast = showToast;
  }

  async saveImageToAlbum(base64DataUrl: string, fileName: string): Promise<string> {
    try {
      await this.requestAlbumPermission();

      const imageBytes = this.decodeImageDataUrl(base64DataUrl);
      const extension = getSafeFileExtension(fileName);
      const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, extension);
      const file = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);

      try {
        const imageBuffer = imageBytes.buffer.slice(imageBytes.byteOffset, imageBytes.byteOffset + imageBytes.byteLength);
        await fileIo.write(file.fd, imageBuffer);
      } finally {
        await fileIo.close(file.fd);
      }

      this.showToast('已保存到相册');
      return uri;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, 'ArkWeb', 'Failed to save photo to album. Cause: %{public}s', JSON.stringify(err));
      this.showToast('保存到相册失败');
      throw new Error(err.message || 'Failed to save photo to album.');
    }
  }

  private async requestAlbumPermission(): Promise<void> {
    try {
      const result = await this.atManager.requestPermissionsFromUser(this.context, ['ohos.permission.WRITE_IMAGEVIDEO']);
      const deniedIndex = result.authResults.findIndex((authResult) => authResult !== 0);
      if (deniedIndex !== -1) {
        throw new Error('Album write permission denied.');
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, 'ArkWeb', 'Failed to request album permission. Cause: %{public}s', JSON.stringify(err));
      throw new Error(err.message || 'Failed to request album permission.');
    }
  }

  private decodeImageDataUrl(base64DataUrl: string): Uint8Array {
    const base64Payload = base64DataUrl.replace(/^data:image\/[a-zA-Z0-9.+-]+;base64,/, '');
    const base64Helper = new util.Base64Helper();
    return base64Helper.decodeSync(base64Payload);
  }
}

function expandShortHex(color: string): string {
  return color.replace(/^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$/, '#$1$1$2$2$3$3');
}

function getSafeFileExtension(fileName: string): string {
  const match = fileName.match(/\.([a-zA-Z0-9]+)$/);
  const extension = match?.[1]?.toLowerCase();
  return extension === 'jpeg' ? 'jpg' : extension || 'jpg';
}

function shouldUseLightIcon(color: string): boolean {
  const normalizedColor = expandShortHex(color.trim());
  const match = normalizedColor.match(/^#([0-9a-fA-F]{6})/);
  if (!match) {
    return true;
  }

  const red = parseInt(match[1].slice(0, 2), 16);
  const green = parseInt(match[1].slice(2, 4), 16);
  const blue = parseInt(match[1].slice(4, 6), 16);
  const luminance = (red * 0.299 + green * 0.587 + blue * 0.114) / 255;
  return luminance < 0.58;
}

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();
  systemBarBridge: SystemBarBridge = new SystemBarBridge();
  albumBridge: AlbumBridge = new AlbumBridge(
    this.getUIContext().getHostContext() as common.UIAbilityContext,
    (message: string): void => {
      this.showToast(message);
    }
  );
  private mainWindow?: window.Window;
  private statusBarContentBaseColor: string = '';

  aboutToAppear(): void {
    webview.WebviewController.setWebDebuggingAccess(true);
    window.getLastWindow(this.getUIContext().getHostContext()).then((mainWindow) => {
      this.mainWindow = mainWindow;
      this.updateStatusBar(DEFAULT_STATUS_BAR_COLOR);
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, 'ArkWeb', 'Failed to get window. Cause: %{public}s', JSON.stringify(err));
    });

    onThemeColorChange = (color: string): void => {
      this.updateStatusBar(color);
    };
  }

  aboutToDisappear(): void {
    onThemeColorChange = (_color: string): void => {};
    try {
      this.controller.deleteJavaScriptRegister('photoBorderSystemBar');
      this.controller.deleteJavaScriptRegister('photoBorderAlbum');
    } catch (err) {
      hilog.warn(DOMAIN, 'ArkWeb', 'Failed to delete JavaScriptProxy. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private updateStatusBar(color: string): void {
    const nextColor = expandShortHex(color.trim());
    if (!this.mainWindow || !nextColor || nextColor === this.statusBarContentBaseColor) {
      return;
    }

    this.statusBarContentBaseColor = nextColor;
    const isLightIcon = shouldUseLightIcon(nextColor);
    this.mainWindow.setWindowSystemBarProperties({
      statusBarColor: TRANSPARENT_SYSTEM_BAR_COLOR,
      statusBarContentColor: isLightIcon ? '#FFFFFF' : '#000000',
      isStatusBarLightIcon: isLightIcon
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, 'ArkWeb', 'Failed to update status bar. Cause: %{public}s', JSON.stringify(err));
    });
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().openToast({ message }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'ArkWeb', 'Failed to show toast. Cause: %{public}s', JSON.stringify(err));
      });
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, 'ArkWeb', 'Failed to show toast. Cause: %{public}s', JSON.stringify(err));
    }
  }

  build() {
    Column() {
      Web({ src: $rawfile('index.html'), controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .javaScriptProxy({
          object: this.systemBarBridge,
          name: 'photoBorderSystemBar',
          methodList: ['setThemeColor'],
          controller: this.controller
        })
        .javaScriptProxy({
          object: this.albumBridge,
          name: 'photoBorderAlbum',
          methodList: [],
          asyncMethodList: ['saveImageToAlbum'],
          controller: this.controller
        })
        .onConsole((event) => {
          hilog.info(
            DOMAIN,
            'ArkWeb',
            'Console[%{public}s] %{public}s (%{public}s:%{public}d)',
            event.message.getMessageLevel(),
            event.message.getMessage(),
            event.message.getSourceId(),
            event.message.getLineNumber()
          );
          return false;
        })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
