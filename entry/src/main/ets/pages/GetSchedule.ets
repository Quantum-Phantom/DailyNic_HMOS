
import { webview } from '@kit.ArkWeb';
import ScheduleManager, { example } from '../utils/TimeTable';
import PasswordDialog from '../view/PasswordDialog';
import accountInfoProvider from '../utils/Encryption';
import BackgroundImage from '../utils/BgImageManager';
import { fillInformationJS } from '../utils/tools';
import UnifiedPreferences, { PASSWORD_KEY, REMIND_KEY, UID_KEY}  from '../utils/UnifyPreference';

@Builder
export function GetBuilder(name: string, param?: string[]) {
  if (param)
    Webview({ title: param[0], url: param[1] });
  else
    Webview();
}

const timeTableQueryJS = `
function getWeekNumber(str) {
    const parts = str.replace(/[^0-9,-]/g, '').split(',');
    const result = [];
    for (const part of parts) {
        if (part.includes('-')) {
            const [start, end] = part.split('-').map(Number);
            for (let i = start; i <= end; i++) {
                result.push(i);
            }
        } else {
            result.push(Number(part));
        }
    }
    return result;
}

function getTimeTable() {
    const timeTable = document.evaluate(
        "/html/body/div[2]/div[3]/div/div/table",
        document,
        null,
        XPathResult.FIRST_ORDERED_NODE_TYPE,
        null).singleNodeValue;
    const rows = timeTable.getElementsByTagName("tr");
    const getClassesOfDay = dayNumber => {
        let classesOfDay = [];
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].hasAttribute("class")) {
                const classesOfWeek = rows[i].getElementsByTagName("td");
                let count = 0;
                const target = Array.from(classesOfWeek).find(elem => {
                    if (!elem.hasAttribute("style")) { return ++count > dayNumber; }
                    return false;
                })
                const classList = Array.from(target.querySelectorAll(".c")).map(element => ({
                    name: element.querySelector(".title").innerText,
                    teacher: Array.from(element.querySelectorAll(".teacher .name")).map(elem => elem.innerText).join(", "),
                    weekOfTerm: getWeekNumber(element.querySelector(".time .week").innerText),
                    timeSpan: getWeekNumber(element.querySelector(".timespan").innerText),
                    dayOfWeek: dayNumber,
                    location: element.querySelector(".classroom .name").innerText.trim(),
                    id: element.querySelector(".number").innerText
                }));
                classesOfDay.push(classList);
            }
        }
        return classesOfDay;
    };
    return ([0, 1, 2, 3, 4, 5, 6].map(i => getClassesOfDay(i)));
}

JSON.stringify(getTimeTable());
`
const timeTableQueryJSShort = `JSON.stringify(getTimeTable());`

const startTimeQueryJS = `
(() => {
  const startTime = new Date(document.getElementById('startDate').innerText);
  return startTime.setHours(0, 0, 0, 0);
})();
`

const getSemesterNameJS = `
function getSemesterText() {
    const targetElement = document.querySelector('.selectize-input.items.full.has-options.has-items .item');
    // 检查元素是否存在
    if (targetElement) {
        // 获取元素内的文本内容
        const semesterText = targetElement.textContent.trim();
        return semesterText;
    } else {
        // 未找到目标元素
        return '自定义名称';
    }
}

// 调用函数执行获取操作
getSemesterText();
`


@Entry
@Component
struct Webview {
  webviewController: webview.WebviewController = new webview.WebviewController();
  title: string = '';
  url: string = '';
  initUrl: string = (UnifiedPreferences.getSync('school') === 'USTC') ?
    'https://id.ustc.edu.cn/cas/login?service=https://jw.ustc.edu.cn/ucas-sso/login' : 'https://hub.hust.edu.cn/';
  timetable: string = '[[[]]]';
  startTime: number = 0;
  webAutoDarkMode: boolean = UnifiedPreferences.getBoolSync('webAutoDarkMode', true);
  @State loadingProgress: number = 0;
  haveTriedLogin: boolean = false;
  autoGetFailed: boolean = false;
  dialogController: CustomDialogController = new CustomDialogController({
    builder: PasswordDialog({
      isFromSetting: false,
      onConfirm: () => {
        this.webviewController.runJavaScript(fillInformationJS, (error, result) => {
        });
      }
    }),
    autoCancel: false
  })


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
          .onErrorReceive((event) => {
            // Only handle loading errors of the main framework to avoid duplicate processing of errors in sub-resources
            this.loadError = event.error.getErrorInfo();
          })
          .onProgressChange((event) => {
            this.loadingProgress = event.newProgress;
          })
          .onPageBegin(() => {
            this.loadError = '';
            if ( /*!this.isTimeTablePage &&*/ this.webviewController.getUrl().startsWith('https://jw.ustc.edu.cn/home')) {
              this.webviewController.loadUrl(this.url);
              console.info(`${this.url}|xxx`);
            }
          })
          .onPageEnd(() => {
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
                this.getUIContext().getPromptAction().showToast({ message: $r('app.string.already_first_page') });
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
        this.webviewController.runJavaScript(getSemesterNameJS, (error, result) => {
          if (error) {
            this.semesterName = '自定义名称';
            return;
          }
          this.semesterName = result.replace(/^["']|["']$/g, '');
        });
        this.webviewController.runJavaScript(timeTableQueryJS, (error, result) => {
          if (result)
            this.timetable = result.replace(/^["']|["']$/g, '');
          this.showSelectTerm = true;
          console.log('???');
          console.log('???' + this.timetable);
        });
      })
      .bindSheet($$this.showSelectTerm, this.selectTerm(), {
        detents: [SheetSize.LARGE],
        preferType: SheetType.CENTER,
        backgroundColor: '#00d00721',
        blurStyle: BlurStyle.Regular,
        enableOutsideInteractive: false,
        enableFloatingDragBar: true,
        title: { title: '获取成功！', subtitle: '请选择一个课表保存' }
      })
    }
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .height(48)
    .width('100%')
  }

  @State showSelectTerm: boolean = false;
  @State semesterName: string = '自定义名称';
  @State selectIndex: number = 0;

  @Builder
  selectTerm() {
    Column() {
      Scroll() {
        ColumnSplit() {
          Row() {
            Image($r('app.media.add'))
              .width(30)
              .height(30)
            Text('新课表…（' + this.semesterName + '）')
              .layoutWeight(1)
          }
          .height(50)
          .width('100%')
          .onClick(() => {
            ScheduleManager.newSemester(this.timetable, Number(this.startTime), this.semesterName);
          })

          ForEach(ScheduleManager.addingTimestamp, (singleTerm: number, index: number) => {
            Row() {
              Image($r('app.media.selected'))
                .width(30)
                .height(30)
                .visibility(index === this.selectIndex ? Visibility.Visible : Visibility.Hidden);
              Text(UnifiedPreferences.getSync(`ScheduleNameAt${singleTerm}`))
                .layoutWeight(1)
              Text(new Date(UnifiedPreferences.getSync(`ScheduleTimeAt${singleTerm}`)).toLocaleDateString('zh-cn'))
            }
            .alignItems(VerticalAlign.Center)
            .height(50)
            .width('100%')
            .onClick(() => {
              this.selectIndex = index;
              console.log(UnifiedPreferences.getSync(`ScheduleDataAt${singleTerm}`, '[][][]'));
            })
          })
        }
        .width('100%')
        .padding({
          top: 10,
          bottom: 10,
          left: 16,
          right: 16
        })
        .backgroundColor($r('app.color.grid_background'))
        .borderRadius(20)
      }
      .padding({ bottom: 16, left: 16, right: 16 })
      .layoutWeight(1)

      Row() {
        Button('追加')
          .onClick(() => {
            ScheduleManager.editSemester(ScheduleManager.addingTimestamp[this.selectIndex], this.timetable, Number(this.startTime), false);
          })
        Button('覆盖')
          .onClick(() => {
            ScheduleManager.editSemester(ScheduleManager.addingTimestamp[this.selectIndex], this.timetable, Number(this.startTime), true);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
    }
  }
}