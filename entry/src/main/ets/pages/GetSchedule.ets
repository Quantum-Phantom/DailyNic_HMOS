
import { webview } from '@kit.ArkWeb';
import { examInfoQueryJS, fillInformationJS, startTimeQueryJS, timeTableQueryJS, pollUntilLoad } from '../utils/TimeTable';
import { obtainedData } from '../constants/ScheduleSources';
import UnifiedPreferences, { PASSWORD_KEY, REMIND_KEY, UID_KEY}  from '../utils/UnifyPreference';
import accountInfoProvider from '../utils/Encryption';
import PasswordDialog from '../view/PasswordDialog';
import BackgroundImage, { presetColor } from '../utils/BgImageManager';

@Builder
export function GetBuilder(name: string, param?: string[]) {
  if (param)
    Webview({ title: param[0], url: param[1] });
  else
    Webview();
}

@Entry
@Component
struct Webview {
  webviewController: webview.WebviewController = new webview.WebviewController();
  title: string = '';
  url: string = '';
  initUrl: string = (UnifiedPreferences.getSync('school') === 'USTC') ? 'https://id.ustc.edu.cn/cas/login?service=https://jw.ustc.edu.cn/ucas-sso/login' : 'https://hub.hust.edu.cn/';
  isTimeTablePage: boolean = false;
  gotTimeTable: boolean = false;
  isExamInfoPage: boolean = false;
  gotExamInfo: boolean = false;
  obtainedData: obtainedData = {timeTable: '', startTime: '0'};
  webAutoDarkMode: boolean = UnifiedPreferences.getBoolSync('webAutoDarkMode', true);
  @State loadingProgress: number = 0;
  haveTriedLogin: boolean = false;
  autoGetFailed: boolean = false;
  dialogController: CustomDialogController = new CustomDialogController({
    builder: PasswordDialog({
      isFromSetting: false,
      onConfirm: () => { this.webviewController.runJavaScript(fillInformationJS, (error, result) => {}); }
    }),
    autoCancel: true
  })

  showMessage(message: string | ResourceStr, duration: number) {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: duration
      });
    } catch (error) {
      console.error(`ShowToast ERROR: [${error.name}] ${error.message}`);
    }
  }

  pathStack: NavPathStack = new NavPathStack();
  @State loadError: string = '';
  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        Web({ src: this.initUrl, controller: this.webviewController })
          .javaScriptProxy({
            object: accountInfoProvider,
            name: "infoProvider",
            methodList: ["getUID", "getPassword"],
            controller: this.webviewController,
            asyncMethodList: []
          })
          .domStorageAccess(true)
          .javaScriptAccess(true)
          .width('100%')
          .height('100%')
          .darkMode(this.webAutoDarkMode ? WebDarkMode.Auto : WebDarkMode.Off)
          .forceDarkAccess(this.webAutoDarkMode)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          .backgroundColor(BackgroundImage.blurLevel === undefined ? undefined : '#00d00721')
          .onLoadIntercept((event) => {
            if (event) {
              let url: string = event.data.getRequestUrl();
              if (url.indexOf('native://webview_error_backward') === 0) {
                if (this.webviewController.accessBackward()) {
                  this.webviewController.backward();
                } else {
                  this.pathStack.pop();
                }
                return true;
              }
            }
            return false;
          })
          .onErrorReceive((event) => {
            // Only handle loading errors of the main framework to avoid duplicate processing of errors in sub-resources
            this.loadError = event.error.getErrorInfo();
          })
          .onProgressChange((event) => {
            this.loadingProgress = event.newProgress;
          })
          .onPageBegin(() => {
            this.loadError = '';
            this.isTimeTablePage = this.webviewController.getUrl().startsWith('https://jw.ustc.edu.cn/for-std/course-table');
            this.isExamInfoPage = this.webviewController.getUrl().startsWith('https://jw.ustc.edu.cn/for-std/exam-arrange');
            if ( /*!this.isTimeTablePage &&*/ this.webviewController.getUrl().startsWith('https://jw.ustc.edu.cn/home')) {
              this.webviewController.loadUrl(this.url);
              console.info(`${this.url}|xxx`);
            }
          })
          .onPageEnd(() => {
            // this.autoGetFailed = true; 调试用：手动获取
            // return;
            if (this.initUrl.startsWith('https://hub.hust.edu.cn/')
              && !(UnifiedPreferences.hasSync(UID_KEY) && UnifiedPreferences.hasSync(PASSWORD_KEY))
              && UnifiedPreferences.getBoolSync(REMIND_KEY, true))
              this.dialogController.open();
            if (!this.haveTriedLogin &&
            this.webviewController.getUrl().startsWith('https://id.ustc.edu.cn/cas/login')) {
              this.haveTriedLogin = true;
              if (!(UnifiedPreferences.hasSync(UID_KEY) && UnifiedPreferences.hasSync(PASSWORD_KEY))) {
                if (UnifiedPreferences.getBoolSync(REMIND_KEY, true))
                  this.dialogController.open();
              } else {
                this.webviewController.runJavaScript(fillInformationJS, (error, result) => {
                  console.info(`自动填写uid：${UnifiedPreferences.getSync(UID_KEY)}`);
                });
              }
            }
            if (this.isTimeTablePage && !this.gotTimeTable) {
              this.webviewController.runJavaScript(startTimeQueryJS, (error, result) => {
                if (error) { /* 理论上这里不会出什么错误 */
                  return;
                }
                console.info(`学期开始的UNIX时间戳是${result}mm`);
                this.obtainedData.startTime = result;
                console.info(`转换后的时间戳是${this.obtainedData.startTime}`);
              });
              pollUntilLoad(() => this.webviewController.runJavaScript(timeTableQueryJS))
                .then((result) => {
                  if (result === 'null') {
                    this.showMessage($r('app.string.auto_get_timetable_fail_msg'), 2000);
                    this.autoGetFailed = true;
                    return;
                  }
                  this.gotTimeTable = true;
                  this.showMessage($r('app.string.get_timetable_succ_msg'), 2000);
                  console.info(`课表是：${result}`);
                  this.obtainedData.timeTable = result;
                  this.pathStack.pop(this.obtainedData);
                });
            }
            if (this.isExamInfoPage && !this.gotExamInfo) {
              this.webviewController.runJavaScript(examInfoQueryJS, (error, result) => {
                if (error) {
                  this.showMessage($r('app.string.get_exam_info_err_msg'), 2000);
                  return;
                }
                if (result === 'null') {
                  this.showMessage($r('app.string.auto_get_exam_info_fail_msg'), 2000);
                  return;
                }
                this.gotExamInfo = true;
                this.showMessage($r('app.string.get_exam_info_succ_msg'), 2000);
                this.obtainedData.timeTable = result;
                this.pathStack.pop(this.obtainedData);
              })
            }
          })

        if (this.loadError !== '') {
          Column() {
            Column() {
              Image($r('app.media.thinking'))
                .layoutWeight(1)
                .objectFit(ImageFit.Contain)
                .constraintSize({ maxWidth: '60%', maxHeight: 300 })
              Text($r('app.string.network_error'))
                .fontWeight(FontWeight.Bold)
                .fontSize(30)
                .fontColor($r('app.color.red'))
              Text($r('app.string.network_error_explain'))
                .textAlign(TextAlign.Center)
                .margin({ top: 6, bottom: 10 })
                .fontColor(this.webAutoDarkMode ? $r('app.color.normal_text') : '#000000')
              Row({ space: 6 }) {
                Button($r('app.string.back_to_last_page'))
                  .onClick(() => {
                    if (this.webviewController.accessBackward()) {
                      this.webviewController.backward();
                    } else {
                      this.webviewController.terminateRenderProcess();
                      this.pathStack.pop();
                    }
                  })
                Button($r('app.string.refresh'))
                  .onClick(() => {
                    this.webviewController.refresh();
                  })
                Button($r('app.string.close_this_hint'))
                  .onClick(() => {
                    this.loadError = '';
                    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.after_close') });
                  })
              }
            }
            .padding({ left: 12, right: 12 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

        Line()
          .visibility(this.loadingProgress == 100 ? Visibility.None : Visibility.Visible)
          .width(`${this.loadingProgress}%`)
          .height(5)
          .startPoint([0, 0])
          .backgroundColor($r('app.color.pink'));
        Row({ space: 5 }) {
          LoadingProgress()
            .width(45)
            .height(45)
            .color($r('app.color.pink'));
          Text($r('app.string.loading'))
            .fontColor($r('app.color.pink'));
        }
        .padding({ left: 5, top: 5 })
        .visibility(this.loadingProgress === 100 ? Visibility.None : Visibility.Visible);
      }
      .height('100%')
      .width('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .title(this.customTitle(), {
      backgroundColor: (BackgroundImage.blurLevel === undefined ? $r(`app.color.shaded_background${BackgroundImage.themeColor}`) : '#00d00721')
    })
    .hideBackButton(true)
    .backgroundColor('#00d00721')
    .backgroundBlurStyle(BackgroundImage.blurLevel)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  @Builder
  customTitle() {
    Row({ space: 6 }) {
      Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
        Image($r('app.media.close'))
          .height(22)
          .draggable(false)
      }
      .height(40)
      .width(40)
      .onClick(() => {
        this.webviewController.terminateRenderProcess();
        this.pathStack.pop();
      })

      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
        Image($r('app.media.back'))
          .height(20)
          .draggable(false)
      }
      .height(40)
      .width(40)
      .parallelGesture(
        GestureGroup(
          GestureMode.Exclusive,
          TapGesture({ count: 1 })
            .onAction(() => {
              if (this.webviewController.accessBackward()) {
                this.webviewController.backward();
              } else {
                this.pathStack.pop();
              }
            }),
          LongPressGesture()
            .onAction(() => {
              if (this.webviewController.accessBackward()) {
                let i: number = -1;
                while (this.webviewController.accessStep(i))
                  i--;
                this.webviewController.backOrForward(i + 1);
              } else {
                this.showMessage($r('app.string.already_first_page'), 500);
              }
            })
        )
      )

      Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
        Image($r('app.media.refresh'))
          .height(22)
          .draggable(false)
      }
      .height(40)
      .width(40)
      .onClick(() => this.webviewController.refresh())

      Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
        Image($r('app.media.get'))
          .height(22)
          .draggable(false)
      }
      .height(40)
      .width(40)
      .onClick(() => {
        if (this.autoGetFailed) {
          if (this.isTimeTablePage && !this.gotTimeTable) {
            this.webviewController.runJavaScript(startTimeQueryJS, (error, result) => {
              if (error) { /* 理论上这里不会出什么错误 */
                return;
              }
              this.obtainedData.startTime = result;
            });
            this.webviewController.runJavaScript(timeTableQueryJS, (error, result) => {
              if (error) {
                this.showMessage($r('app.string.get_timetable_err_msg'), 2000);
                return;
              }
              if (result === 'null') {
                this.showMessage($r('app.string.auto_get_timetable_fail_msg'), 2000);
                return;
              }
              this.gotTimeTable = true;
              this.obtainedData.timeTable = result;
              this.pathStack.pop(this.obtainedData);
            });
          }
          if (this.isExamInfoPage && !this.gotExamInfo) {
            this.webviewController.runJavaScript(examInfoQueryJS, (error, result) => {
              if (error) {
                this.showMessage($r('app.string.get_exam_info_err_msg'), 2000);
                return;
              }
              if (result === 'null') {
                this.showMessage($r('app.string.auto_get_exam_info_fail_msg'), 2000);
                return;
              }
              this.gotExamInfo = true;
              this.showMessage($r('app.string.get_exam_info_succ_msg'), 2000);
              this.obtainedData.timeTable = result;
              this.pathStack.pop(this.obtainedData);
            })
          }
        } else {
          this.showMessage($r('app.string.auto_get_info'), 2000);
        }
      })
    }
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .height(48)
    .width('100%')
  }
}
