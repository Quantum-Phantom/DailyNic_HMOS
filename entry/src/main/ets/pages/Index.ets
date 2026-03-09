
import { application, common, contextConstant, Want } from '@kit.AbilityKit'
import { LengthUnit } from '@kit.ArkUI'
import { fileIo, storageStatistics } from '@kit.CoreFileKit'

import { GridData, otherGridDataList } from '../constants/GridListDataSources'
import { ListDataConstants } from '../constants/ListDataConstants'
import * as ScheduleSources from '../constants/ScheduleSources'
import SettingsData from '../constants/SettingsSources'

import { CheckInTools } from '../utils/CheckIn'
import examManager, { examAttribute } from '../utils/ExamManager'
import * as FunctionOrder from '../utils/FunctionOrder'
import ScheduleManager from '../utils/ScheduleManager'
import * as tools from '../utils/tools'
import UnifiedPreferences, { millisecondsPerWeek } from '../utils/UnifyPreference'
import WriteCalendar from '../utils/WriteCalendar'

import BackgroundImage, { presetColor } from '../utils/BgImageManager'
import GridComponent from '../view/GridComponent'
import PasswordDialog from '../view/PasswordDialog'
import ItemData from '../view/SettingsComponent'

import { setUSTCLink, setHUSTLink } from '../constants/Links'
import display from '@ohos.display'

// 滚动条参数
enum ScrollPosition {
  start = 0,
  center = 1,
  end = 2
}

// 主界面UI
@Entry
@Component
struct Index {
  private windowRect: display.Display = display.getDefaultDisplaySync();

  @State currentIndex: number = 0; // 当前标签索引 (从0开始), 初始值即为默认标签索引
  private tabsController: TabsController = new TabsController();

  dialogController: CustomDialogController = new CustomDialogController({
    builder: PasswordDialog({
      isFromSetting: true
    }),
    autoCancel: false,
    gridCount: 4
  });

  /**
   * 函数: 构建 Tab 按钮
   * @param title 按钮文字
   * @param index 标签索引 (从0开始)
   * @param selectedImg 按钮图片 (选中时)
   * @param normalImg 按钮图片 (未选中时)
   */
  @Builder tabBuilder(title: string | Resource, index: number, selectedImg: Resource, normalImg: Resource) {
    Column() {
      // 按钮图片
      Image(this.currentIndex === index ? selectedImg : normalImg)
        .width(28)
        .height(28)
        .objectFit(ImageFit.Contain)
        .draggable(false)
      // 按钮文字
      Text(title)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? $r('app.color.active_text') : $r('app.color.normal_text'))
    }
    .justifyContent(FlexAlign.Center)
    .height('52vp')
    .width('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .onClick(() => {
      this.currentIndex = index
      this.tabsController.changeIndex(this.currentIndex);
    })
  }

  /**
   * 全局资源: 首页
   */
  @State checkInTotal: number = 0;
  @State checkInConsecutive: number = 0;
  @State checkedInToday: boolean = false;
  @State checkInContent: string = ''; // 签到后展示的随机内容

  @State todayCourse: ScheduleSources.classAttribute[] = [];
  @State tomorrowCourse: ScheduleSources.classAttribute[] = [];
  @State exams: examAttribute[] = [];

  @State showCheckIn: boolean = UnifiedPreferences.getBoolSync('showCheckIn', true);
  @State showRecentCourse: boolean = UnifiedPreferences.getBoolSync('showRecentCourse', true);
  @State showExamDetail: boolean = UnifiedPreferences.getBoolSync('showExamDetail', true);
  @State webAutoDarkMode: boolean = UnifiedPreferences.getBoolSync('webAutoDarkMode', true);
  @State webBackPress: boolean = UnifiedPreferences.getBoolSync('webBackPress', true);

  private context: Context = this.getUIContext().getHostContext() as common.UIAbilityContext;
  @State currentTime: Date = new Date();

  aboutToAppear(): void {
    // 快捷方式跳转
    this.getUIContext().getHostContext()?.eventHub.on('navigation', (path: string) => {
      let paths = this.pageInfo.getAllPathName();
      if (paths.slice().pop() === path) {
        return;
      }
      this.pageInfo.pushPath({ name: path }, false);
    });
    // 刷新点击次数显示
    FunctionOrder.refreshFunc();
    this.copyMostUsedFunc = FunctionOrder.mostUsedFunc;
    // 获取签到和课表
    ScheduleSources.initSchedulePre();
    const GeneratedDestructArray_1 = CheckInTools.loadCheckInOnStartup();
    this.checkInTotal = GeneratedDestructArray_1[0];
    this.checkInConsecutive = GeneratedDestructArray_1[1];
    this.checkedInToday = GeneratedDestructArray_1[2];
    this.checkInContent = this.checkedInToday ? GeneratedDestructArray_1[3] : '';
    this.refreshInfo();
    // 初始化日历
    WriteCalendar.initializeCalendar(this.getUIContext());
    //初始化背景
    BackgroundImage.init(this.context);
    // 首次启动提示
    if (UnifiedPreferences.getBoolSync('InitialLaunch', true)) {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/Declaration' })
        .catch((err: Error) => { console.error(`Router ERROR: [${err.name}] ${err.message}`) })
    } else if (UnifiedPreferences.getSync('AppVersion') !== '2.0.0') {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/UpdateLog' })
        .catch((err: Error) => { console.error(`Router ERROR: [${err.name}] ${err.message}`) })
    }
  }

  /**
   * 全局资源: 功能
   */
  @State listPosition: number = ScrollPosition.start;
  @State scrollPosition: number = ScrollPosition.start;
  @State currentListIndex: number = 0;
  private scrollerForScroll: Scroller = new Scroller();
  private scrollerForList: Scroller = new Scroller();
  private scrollerForTitle: Scroller = new Scroller();

  @Builder listBuilder() {
    Row() {
      List({ space: 16, scroller: this.scrollerForTitle }) {
        ForEach(ListDataConstants.TITLE_LIST, (item: string, index) => {
          ListItem() {
            Column() {
              Text(item)
                .fontColor(this.currentListIndex === index ? $r('app.color.active_text') : $r('app.color.normal_text'))
                .fontSize('16fp')
                .fontWeight(this.currentListIndex === index ? FontWeight.Bold : FontWeight.Normal)
                .margin({ top: '15vp' })

              Divider()
                .color($r('app.color.active_text'))
                .strokeWidth(2)
                .width(this.getUIContext().getMeasureUtils().measureText({ textContent: item, fontSize: '16fp' }).toString() + 'px')
                .margin({ top: '4vp' })
                .visibility(this.currentListIndex === index ? Visibility.Visible : Visibility.Hidden)
            }
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.scrollerForList.scrollToIndex(index);
              this.scrollerForScroll.scrollEdge(Edge.Bottom);
              this.scrollerForTitle.scrollToIndex(index);
              this.currentListIndex = index;
            })
          }
        }, (item: string, index: number) => index + JSON.stringify(item))
      }
      .width('100%')
      .height('51vp')
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .fadingEdge(true)
      .contentStartOffset(6)
      .contentEndOffset(6)
    }
    .margin({ bottom: '8vp' })
    .padding({ left: '10vp', right: '10vp' })
    .backgroundColor(BackgroundImage.blurLevel === undefined ? $r('app.color.normal_background') : undefined)
    .backgroundBlurStyle(BackgroundImage.blurLevel)
    .borderRadius(20)
  }

  @State copyMostUsedFunc: GridData = FunctionOrder.mostUsedFunc;
  onPageShow(): void {
    storageStatistics.getCurrentBundleStats().then((dataSize: storageStatistics.BundleStats) => {
      this.cacheSize = tools.formatBytes(dataSize.cacheSize, 2, false);
    });
  }

  /**
   * 全局资源: 设置
   */
  @State cacheSize: string = '计算中…'; // 未初始化时
  clearCache = async () => {
    this.cacheSize = '清理中…'
    let moduleContext: common.Context;
    moduleContext = await application.createModuleContext(this.context, 'entry');
    // 缓存路径/data/storage/el2/base/cache
    // 缓存路径/data/storage/el2/base/cache/web
    // 缓存路径/data/storage/el2/base/haps/entry/cache
    let paths: Array<string> = [moduleContext.cacheDir, moduleContext.cacheDir + '/web', this.context.cacheDir];
    // 缓存路径/data/storage/el1/base/cache
    moduleContext.area = contextConstant.AreaMode.EL1;
    paths.push(moduleContext.cacheDir);
    // 缓存路径/data/storage/el1/base/haps/entry/cache
    this.context.area = contextConstant.AreaMode.EL1;
    paths.push(this.context.cacheDir);
    this.context.area = contextConstant.AreaMode.EL2;

    // 遍历paths数组，彻底删除每个文件夹下的缓存数据
    for (let i = 0; i < paths.length; i++) {
      let path = paths[i];
      fileIo.listFile(path).then((filenames) => {
        for (let j = 0; j < filenames.length; j++) {
          let dirPath = path + '/' + filenames[j];
          if (dirPath === '/data/storage/el2/base/cache/web' || dirPath === '/data/storage/el2/base/cache/web/Cookies')
            continue;
          // 判断是否为文件夹
          let isDirectory: boolean = false;
          try {
            isDirectory = fileIo.statSync(dirPath).isDirectory();
          } catch (err) {
            console.error(`remove file failed with error message: ${err.message}`);
          }
          if (isDirectory) {
            fileIo.rmdirSync(dirPath);
          } else {
            fileIo.unlink(dirPath).catch((err: Error) => {
              console.error(`remove file failed with error message: ${err.message}`);
            });
          }
        }
        // 清理完成后再次计算
        if (i === paths.length - 1)
          storageStatistics.getCurrentBundleStats().then((dataSize: storageStatistics.BundleStats) => {
            this.cacheSize = tools.formatBytes(dataSize.cacheSize, 2, false);
        });
      });
    }
  }

  @Builder settingCell(item: ItemData) {
    Row() {
      Row() {
        Image(item.img)
          .height('22vp')
          .margin({ left: '16vp', right: '12vp' })
          .draggable(false)
        Text(item.title)
          .fontSize('16fp')
          .fontColor($r('app.color.normal_text'))
        if (item.id === 12) { // 清理缓存
          Text(' (' + this.cacheSize + ')')
            .fontSize('16fp')
            .fontColor($r('app.color.normal_text'))
        }
      }

      if (item.others === undefined) {
        Image($r('app.media.right_arrow'))
          .width('12vp')
          .height('12vp')
          .draggable(false)
      } else if (item.id === 2) {
        Toggle({ type: ToggleType.Switch, isOn: $$this.showCheckIn })
          .selectedColor(presetColor[BackgroundImage.themeColor][2])
          .onChange((value: boolean) => {
            UnifiedPreferences.putSync('showCheckIn', value);
          });
      } else if (item.id === 3) {
        Toggle({ type: ToggleType.Switch, isOn: $$this.showRecentCourse })
          .selectedColor(presetColor[BackgroundImage.themeColor][2])
          .onChange((value: boolean) => {
            UnifiedPreferences.putSync('showRecentCourse', value);
          });
      } else if (item.id === 4){
        Toggle({ type: ToggleType.Switch, isOn: $$this.showExamDetail })
          .selectedColor(presetColor[BackgroundImage.themeColor][2])
          .onChange((value: boolean) => {
            UnifiedPreferences.putSync('showExamDetail', value);
          });
      } else if (item.id === 7) {
        Toggle({ type: ToggleType.Switch, isOn: $$this.webAutoDarkMode })
          .selectedColor(presetColor[BackgroundImage.themeColor][2])
          .onChange((value: boolean) => {
            UnifiedPreferences.putSync('webAutoDarkMode', value);
          });
      } else { // item.id === 8
        Toggle({ type: ToggleType.Switch, isOn: $$this.webBackPress })
          .selectedColor(presetColor[BackgroundImage.themeColor][2])
          .onChange((value: boolean) => {
            UnifiedPreferences.putSync('webBackPress', value);
          });
      }
    }
    .justifyContent(FlexAlign.SpaceBetween)
    .width('100%')
    .padding({
      left: '8vp',
      right: '22vp'
    })
  }

  /*
   * 常用功能
   */
  @State termState: number = 0; // 0：未开始，1：进行中，2: 进行中但今天无课程，3: 进行中但今天的课都上完了，4：已结束
  private currentWeek: number = 1;
  private todayBeginTime: number = 0;
  refreshInfo() {
    this.currentTime = new Date();
    const termStartTime: number = ScheduleManager.semesters[ScheduleManager.defaultSemester].beginTime;
    this.todayBeginTime = new Date(this.currentTime).setHours(0, 0, 0, 0);
    if (this.currentTime.getTime() < termStartTime) {
      this.termState = 0;
      this.currentWeek = 1;
      this.todayCourse = [];
      this.tomorrowCourse = [];
    } else if (this.currentTime.getTime() > termStartTime + ScheduleManager.semesters[ScheduleManager.defaultSemester].totalWeekNum * millisecondsPerWeek) {
      this.termState = 4;
      this.currentWeek = 1;
      this.todayCourse = [];
      this.tomorrowCourse = [];
    } else {
      this.currentWeek = Math.ceil((this.currentTime.getTime() - termStartTime) / millisecondsPerWeek);
      this.todayCourse = ScheduleManager.getDefaultClassByDay(this.currentWeek, this.currentTime.getDay(), true);
      this.tomorrowCourse = ScheduleManager.getDefaultClassByDay(this.currentWeek + (this.currentTime.getDay() === 6 ? 1 : 0), (this.currentTime.getDay() + 1) % 7, true);
      if (this.todayCourse.length === 0)
        this.termState = 2;
      else if (this.currentTime.getTime() > this.todayBeginTime + ScheduleSources.commonClassStamp[this.todayCourse[this.todayCourse.length - 1].timeSpan[this.todayCourse[this.todayCourse.length - 1].timeSpan.length - 1]][1])
        this.termState = 3;
      else
        this.termState = 1;
    }

    examManager.readStoredExam();
    this.exams = examManager.allExamInfo;
    for (let i = this.exams.length - 1; i >= 0; i--)
      if (this.currentTime.getTime() > this.exams[i].endTimeStamp)
        this.exams.splice(i, 1);
  }

  showMessage(message: string | ResourceStr, duration?: number) {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: duration
      });
    } catch (error) {
      console.error(`ShowToast ERROR: [${error.name}] ${error.message}`);
    }
  }

  /*
   * 日历权限相关
   */

  /**
   * 页面: 首页
   */
  @Builder pageStart() {
    List({ space: 10 }) {
      // 每日签到
      if (this.showCheckIn) {
        ListItem() {
          Column() {
            Row() {
              Text($r('app.string.daily_checkin'))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.normal_text'))
            }
            .width('100%')
            .margin({ top: 15, bottom: 10 })
            .justifyContent(FlexAlign.Center)

            Row() {
              Text(this.checkInContent)
                .fontColor($r('app.color.active_text'))
                .fontSize(20)
                .textShadow({ radius: 1 })
                .lineSpacing({ value: 10, unit: LengthUnit.FP })
            }
            .width('80%')
            .margin({ bottom: 10 })
            .justifyContent(FlexAlign.Center)

            Row() {
              Button(this.checkedInToday ? $r('app.string.checked_in') : $r('app.string.check_in'))
                .buttonStyle(this.checkedInToday ? ButtonStyleMode.NORMAL : ButtonStyleMode.EMPHASIZED)
                .enabled(!this.checkedInToday)
                .onClick(() => {
                  const GeneratedDestructArray_1 = CheckInTools.doCheckIn()
                  this.checkInTotal = GeneratedDestructArray_1[0]
                  this.checkedInToday = true
                  this.checkInConsecutive = GeneratedDestructArray_1[1]
                  this.checkInContent = GeneratedDestructArray_1[2]
                })
            }
            .width('90%')
            .margin({ bottom: 10 })
            .justifyContent(FlexAlign.Center)

            Row() {
              Text($r('app.string.checkin_count_d', this.checkInTotal))
                .fontSize(12)
                .align(Alignment.Start)

              Blank()

              Text($r('app.string.checkin_consecutive_d', this.checkInConsecutive))
                .fontSize(12)
                .align(Alignment.End)
            }
            .width('80%')
            .margin({ bottom: 10 })
          }
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .borderRadius(20)
        .backgroundColor(BackgroundImage.blurLevel === undefined ? $r('app.color.grid_background') : undefined)
        .backgroundBlurStyle(BackgroundImage.blurLevel);
      }

      // 你的课表
      ListItem() {
        Column() {
          Row() {
            if (this.showRecentCourse) {
              Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
                Image($r('app.media.refresh'))
                  .height(20)
                  .width(20)
                  .draggable(false)
              }
              .height(36)
              .width(36)
              .onClick(() => {
                this.refreshInfo();
              })
            } else {
              Blank().width(36);
            }

            Blank()

            Text($r('app.string.local_schedule'))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.normal_text'))

            Blank()

            Image($r('app.media.right_arrow'))
              .height(28)
              .width(28)
              .margin({ left: 8 })
              .objectFit(ImageFit.Contain)
              .draggable(false)
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
          .onClick(() => {
            if (this.pageInfo.popToName('Schedule') === -1) {
              this.pageInfo.clear();
              this.pageInfo.pushPath({ name: 'Schedule',
                param: UnifiedPreferences.getNumberSync('GridHeight', px2vp(this.windowRect.height) - 75) });
            }
            // this.getUIContext().getRouter().pushUrl({ url: 'pages/Schedule' })
            //   .catch((err: Error) => { console.error(`Router ERROR: [${err.name}] ${err.message}`) })
          })

          if (this.showRecentCourse) {
            Divider();

            if (this.termState === 0) {
              Column() {
                Image($r('app.media.no_course_term_not_start'))
                  .height(75)
                  .interpolation(ImageInterpolation.Medium)
                  .draggable(false);
                Text($r('app.string.no_class_term_not_start'))
                  .textAlign(TextAlign.Center);
              }
              .margin({ top: 12, bottom: 12 });
            } else if (this.termState === 2) {
              Column() {
                Image($r('app.media.no_course_today'))
                  .height(75)
                  .draggable(false);
                Text($r('app.string.no_class_today'))
                  .textAlign(TextAlign.Center);
              }
              .margin({ top: 12, bottom: 12 });
            } else if (this.termState === 4) {
              Column() {
                Image($r('app.media.no_course_term_end'))
                  .height(75)
                  .interpolation(ImageInterpolation.Medium)
                  .draggable(false);
                Text($r('app.string.no_class_term_end'))
                  .textAlign(TextAlign.Center);
              }
              .margin({ top: 12, bottom: 12 });
            } else {
              ForEach(this.todayCourse, (course: ScheduleSources.classAttribute, index: number) => {
                if (this.currentTime.getTime() < this.todayBeginTime +
                ScheduleSources.commonClassStamp[course.timeSpan[course.timeSpan.length - 1]][1] + 1800000) {
                  Row() {
                    Column() {
                      Line()
                        .stroke((course.color.length === 9) ? `#${course.color.slice(3)}` :
                          ((course.color.length === 5) ? `#${course.color.slice(2)}` : course.color))
                        .width(6)
                        .height(20)
                        .strokeLineCap(LineCapStyle.Round)
                        .strokeWidth(6)
                        .startPoint([3, 0])
                        .endPoint([3, 20])
                        .margin({ right: 4 });
                    }
                    .alignItems(HorizontalAlign.End)
                    .width('5%');

                    Column() {
                      Text(course.name)
                        .textAlign(TextAlign.Start)
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis });

                      if (this.currentTime.getTime() <
                        this.todayBeginTime + ScheduleSources.commonClassStamp[course.timeSpan[0]][0] &&
                        this.currentTime.getTime() >
                          this.todayBeginTime + ScheduleSources.commonClassStamp[course.timeSpan[0]][0] - 1800000) {
                        Text($r('app.string.class_soon'))
                          .fontColor($r('app.color.green'));
                      } else if (this.currentTime.getTime() >
                        this.todayBeginTime + ScheduleSources.commonClassStamp[course.timeSpan[0]][0] &&
                        this.currentTime.getTime() < this.todayBeginTime +
                        ScheduleSources.commonClassStamp[course.timeSpan[course.timeSpan.length - 1]][1]) {
                        Text($r('app.string.class_in_session'))
                          .fontColor($r('app.color.bright_blue'));
                      } else if (this.currentTime.getTime() >
                        this.todayBeginTime + ScheduleSources.commonClassStamp[course.timeSpan[course.timeSpan.length - 1]][1]) {
                        Text($r('app.string.class_end'))
                          .fontColor($r('app.color.red'));
                      } else {
                        Text($r('app.string.class_not_start'))
                          .fontColor($r('app.color.green'));
                      }
                    }
                    .width('45%')
                    .alignItems(HorizontalAlign.Start)
                    .padding({ right: 10 });

                    Column() {
                      Text(`\udb81\uddf3 ${course.teacher}`)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .visibility(course.teacher === '' ? Visibility.None : Visibility.Visible);

                      Text(`\udb80\uddb8 ${course.location}`)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .visibility(course.location === '' ? Visibility.None : Visibility.Visible);

                      Text(`\udb80\udfdc ${ScheduleSources.commonClassTime[course.timeSpan[0]][0]}~${ScheduleSources.commonClassTime[course.timeSpan[course.timeSpan.length -
                        1]][1]}`)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis });
                    }
                    .width('45%')
                    .alignItems(HorizontalAlign.Start);
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Start)
                  .margin({ top: 7, bottom: 7 });

                  if (index < this.todayCourse.length - 1) {
                    Divider()
                      .width('90%');
                  }
                }
              });
              if (this.termState === 3) {
                Column() {
                  Image($r('app.media.course_finish_today'))
                    .height(75)
                    .interpolation(ImageInterpolation.Medium)
                    .draggable(false);
                  Text($r('app.string.class_finish_today'));
                }
                .margin({ top: 12, bottom: 12 });
              }
            }


            if (this.tomorrowCourse.length > 0) {
              Row() {
                Text($r('app.string.tomorrow_class'))
                  .fontSize(15)
                  .margin({left: 10, right: 10})
                  .fontColor($r('app.color.pink'));
                Divider();
              }

              ForEach(this.tomorrowCourse, (course: ScheduleSources.classAttribute, index) => {
                if (index > 0) {
                  Divider()
                    .width('90%');
                }
                Row() {
                  Column() {
                    Text(course.name)
                      .textAlign(TextAlign.Start)
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                  .width('50%')
                  .alignItems(HorizontalAlign.Start)
                  .padding({ right: 10 });

                  Column() {
                    Text(`\udb81\uddf3 ${course.teacher}`)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .visibility(course.teacher === '' ? Visibility.None : Visibility.Visible);

                    Text(`\udb80\uddb8 ${course.location}`)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .visibility(course.location === '' ? Visibility.None : Visibility.Visible);

                    Text(`\udb80\udfdc ${ScheduleSources.commonClassTime[course.timeSpan[0]][0]}~${ScheduleSources.commonClassTime[course.timeSpan[course.timeSpan.length - 1]][1]}`)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('50%')
                  .alignItems(HorizontalAlign.Start);
                }
                .width('90%')
                .margin({ top: 7, bottom: 7 })
              });
            }
          }
        }
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .borderRadius(20)
      .margin({ top: 5 })
      .backgroundColor(BackgroundImage.blurLevel === undefined ? $r('app.color.grid_background') : undefined)
      .backgroundBlurStyle(BackgroundImage.blurLevel);

      // 考试信息
      ListItem() {
        Column() {
          Row() {
            if (this.showExamDetail) {
              Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
                Image($r('app.media.refresh'))
                  .height(20)
                  .width(20)
                  .draggable(false)
              }
              .height(36)
              .width(36)
              .onClick(() => {
                this.refreshInfo();
              });
            } else {
              Blank().width(36);
            }

            Blank()

            Text($r('app.string.exam_detail'))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.normal_text'))

            Blank()

            Image($r('app.media.right_arrow'))
              .height(28)
              .width(28)
              .margin({ left: 8 })
              .objectFit(ImageFit.Contain)
              .draggable(false)
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
          .onClick(() => {
            if (this.pageInfo.popToName('ExamDetail') === -1) {
              this.pageInfo.clear();
              this.pageInfo.pushPath({ name: 'ExamDetail' });
            }
          })

          if (this.showExamDetail) {
            Divider();
            if (this.exams.length === 0) {
              Column() {
                Image($r('app.media.no_exam1'))
                  .height(75)
                  .interpolation(ImageInterpolation.Medium)
                  .draggable(false)
                Text($r('app.string.no_exam_info1'));
              }
              .margin({ top: 12, bottom: 12 });
            } else {
              ForEach(this.exams, (singleExam: examAttribute, index: number) => {
                Row() {
                  if (this.currentTime.getTime() < singleExam.beginTimeStamp) {
                    Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.End }) {
                      Text() {
                        Span(tools.formatTimeDiff(this.currentTime.getTime(), singleExam.beginTimeStamp, 0).toString())
                          .fontSize(36)
                        Span($r('app.string.day'))
                          .fontSize(18)
                      }
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.green'))

                      Text() {
                        Span(Number((tools.formatTimeDiff(this.currentTime.getTime(), singleExam.beginTimeStamp, 1)
                          + tools.formatTimeDiff(this.currentTime.getTime(), singleExam.beginTimeStamp, 2) / 60).toExponential(1)).toString())
                          .fontSize(28)
                        Span($r('app.string.hour'))
                          .fontColor($r('app.color.hour'))
                          .fontSize(14)
                      }
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.hour'))
                    }
                    .width('30%');
                  } else {
                    Text($r('app.string.exam_processing'))
                      .fontSize(20)
                      .fontColor($r('app.color.transparent_text'))
                      .width('30%')
                      .textAlign(TextAlign.Start);
                  }

                  Column() {
                    Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.End }) {
                      Text(singleExam.name)
                        .fontSize(18)
                        .fontWeight(FontWeight.Bold)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ right: 5 })
                      Text(singleExam.type)
                        .fontSize(16)
                    }
                    .margin({ bottom: 5 })

                    Text('\udb80\uddb8 ' + singleExam.campus + singleExam.building + singleExam.classroom)
                      .visibility(singleExam.campus + singleExam.building + singleExam.classroom === '' ? Visibility.None : Visibility.Visible);
                    Text('\udb80\udfdc ' + singleExam.date)
                      .visibility(singleExam.date === '' ? Visibility.None : Visibility.Visible);
                  }
                  .width('70%')
                  .alignItems(HorizontalAlign.Start);
                }
                .padding({ left: 15, right: 5 })
                .margin({ top: 7, bottom: 7 })
                .borderRadius(20);

                if (index < this.exams.length - 1) {
                  Divider().padding({ left: 15, right: 15 });
                }
              })
            }
          }
        }
      }
      .width('100%')
      .borderRadius(20)
      .margin({ top: 5 })
      .backgroundColor(BackgroundImage.blurLevel === undefined ? $r('app.color.grid_background') : undefined)
      .backgroundBlurStyle(BackgroundImage.blurLevel);

      ListItem() {
        Text($r('app.string.not_newest'))
          .fontColor($r('app.color.transparent_text'))
          .fontSize(12)
      }
      .margin({ bottom: 13 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .padding({ left: 12, right: 12 })
    .margin({ top: 8 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * 页面: 功能
   */
  @Builder pageFunction() {
    Column() {
      Scroll(this.scrollerForScroll) {
        Column() {
          // 常用区 Grid
          GridComponent({ gridData: this.copyMostUsedFunc, gridIndex: -1, pageInfo: this.pageInfo,
            copyMostUsedFunc: this.copyMostUsedFunc })
          // 常用区下面的所有功能区 GridComponent
          this.listBuilder();
          List({ scroller: this.scrollerForList }) {
            ForEach(otherGridDataList, (item: GridData, index: number) => {
              GridComponent({
                gridData: item,
                gridIndex: index,
                pageInfo: this.pageInfo,
                copyMostUsedFunc: this.copyMostUsedFunc
              })
            }, (item: GridData,index:number) => index + JSON.stringify(item))

            ListItem().height('100%')
          }
          // .padding({ bottom: '40vp' })
          .borderRadius({ topLeft: 20, topRight: 20 })
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)
          .onReachStart(() => {
            this.listPosition = ScrollPosition.start;
          })
          .onReachEnd(() => {
            this.listPosition = ScrollPosition.end;
          })
          .onScrollIndex((start: number) => {
            this.currentListIndex = start
            this.scrollerForTitle.scrollToIndex(this.currentListIndex);
          })
          .onScrollFrameBegin((offset: number) => {
            if (this.currentListIndex === ListDataConstants.TITLE_LIST.length - 1 && offset > 0) {
              return { offsetRemain: 0 }
            }
            if (!((this.listPosition === ScrollPosition.start && offset < 0) ||
              (this.listPosition === ScrollPosition.end && offset > 0))) {
              this.listPosition = ScrollPosition.center;
            }
            if (this.scrollPosition === ScrollPosition.end &&
              (this.listPosition != ScrollPosition.start || offset > 0)) {
              return { offsetRemain: offset };
            } else {
              this.scrollerForScroll.scrollBy(0, offset)
              return { offsetRemain: offset };
            }
          })
          .width('100%')
          .height("calc(100% - 59vp)") // this.listBuilder的高度：51 + 8 = 59
        }
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.None)
      .onWillScroll((yOffset: number) => {
        if (!((this.scrollPosition === ScrollPosition.start && yOffset < 0) || (this.scrollPosition === ScrollPosition.end && yOffset > 0))) {
          this.scrollPosition = ScrollPosition.center;
        }
      })
      .onScrollEdge((side: Edge) => {
        if (side === Edge.Top) {
          this.scrollPosition = ScrollPosition.start;
        } else if (side === Edge.Bottom) {
          this.scrollPosition = ScrollPosition.end;
        }
      })
      .onScrollFrameBegin(offset => {
        if (this.scrollPosition === ScrollPosition.end) {
          return { offsetRemain: 0 };
        } else {
          return { offsetRemain: offset };
        }
      })
    }
    .width('100%')
    .height('100%')
    .margin({ top: 8 })
    .padding({ left: '12vp', right: '12vp' })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * 页面: 设置
   */
  @Builder pageSettings() {
    List({ space: 12 }) {
      ForEach(SettingsData.getSettingListData(), (item: ItemData[], _index: number) => {
        ListItemGroup() {
          ForEach(item, (cell: ItemData, _cellIndex) => {
            ListItem() {
              this.settingCell(cell)
            }
            .height('48vp')
            .onClick(() => this.settingAction(cell))
          })
        }
        .divider({
          strokeWidth: '0.6vp',
          color: $r('sys.color.comp_divider'),
          startMargin: '12vp',
          endMargin: '12vp'
        })
        .backgroundColor(BackgroundImage.blurLevel === undefined ? $r('app.color.grid_background') : undefined)
        .backgroundBlurStyle(BackgroundImage.blurLevel)
        .borderRadius(20)

      }/*, (item: ItemData) => JSON.stringify(item)*/)

      ListItem().height(50)
    }
    .height('100%')
    .width('100%')
    .padding({ left: 12, right: 12 })
    .margin({ top: 8 })
    .scrollBar(BarState.Auto)
    .overlay(this.settingExitButton(), { align: Alignment.Bottom })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  settingAction(cell: ItemData) {
    switch (cell.id) { // 根据 cell.id 区分设置项
      case 0:
        this.getUIContext().showTextPickerDialog({
          selected: (UnifiedPreferences.getSync('school', 'USTC') === 'USTC' ? 1 : 0),
          range: ['华中科技大学', '中国科学技术大学'],
          defaultPickerItemHeight: 36,
          canLoop: false,
          onAccept: (value: TextPickerResult) => {
            switch(value.index) {
              case 1:
                UnifiedPreferences.putSync('school', 'USTC');
                setUSTCLink();
                break;
              case 0:
                UnifiedPreferences.putSync('school', 'HUST');
                setHUSTLink();
                break;
            }
            this.showMessage(`已更改为 ${value.value}`);
          }
        });
        break;

      case 1:
        this.dialogController.open();
        break;
      case 2:
      case 3:
      case 4:
        break;

      case 5:
        if (this.pageInfo.popToName('ThemeSetting') === -1) {
          this.pageInfo.clear();
          this.pageInfo.pushPath({ name: 'ThemeSetting', param: [this.windowRect.width, this.windowRect.height] });
        }
        break;

      case 6:
        // 选择最常访问显示个数
        this.getUIContext().showTextPickerDialog({
          selected: FunctionOrder.maxRecord - 1,
          range: tools.getContArray([[1, 20]], true) as string[], // 在此处修改允许用户选择的最大显示数量上限！！（现在是20）
          defaultPickerItemHeight: 36,
          canLoop: false,
          onAccept: (value: TextPickerResult) => {
            FunctionOrder.setMaxRecord(Number(value.value));
            this.showMessage(`已更改为 ${value.value}`);
            FunctionOrder.refreshFunc(); // 刷新点击次数显示
            this.copyMostUsedFunc = FunctionOrder.mostUsedFunc;
          }
        })
        break;

      case 7:
      case 8:
        break;

      case 9:
        if (WriteCalendar.askForCalendar(1)) {
          WriteCalendar.deleteCalendar();
        }
        break;

      case 10:
        if (WriteCalendar.askForCalendar(2)) {
          WriteCalendar.setClassCalendar();
        }
        break;

      case 11:
        if (WriteCalendar.askForCalendar(3)) {
          WriteCalendar.setExamCalendar();
        }
        break;

      case 12:
        this.clearCache();
        break;

      case 13:
        // 帮助
        if (this.pageInfo.popToName('Help') === -1) {
          this.pageInfo.clear();
          this.pageInfo.pushPath({ name: 'Help' });
        }
        break;

      case 14:
        // 关于
        if (this.pageInfo.popToName('About') === -1) {
          this.pageInfo.clear();
          this.pageInfo.pushPath({ name: 'About' });
        }
        break;

      case 15:
        // 进入恢复模式
        UnifiedPreferences.putSync('RecoveryMode', true);
        let applicationContext = (this.getUIContext().getHostContext() as common.UIAbilityContext).getApplicationContext();
        let want: Want = {
          bundleName: 'com.nic.dailynic',
          abilityName: 'EntryAbility'
        };
        try {
          applicationContext.restartApp(want);
        } catch (error) {
          console.error(`restartApp fail, error: ${JSON.stringify(error)}`);
          if (error.code === 16000064) {
            const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            context.terminateSelf((err) => {
              if (!err) {
                context.getApplicationContext().killAllProcesses().catch((error: Error) => {
                  console.error(`Quitting ERROR: [${error.name}] ${error.message}`);
                })
              }
            });
          }
        }
        break;

      default:
        this.showMessage($r('app.string.under_construction'));
        break;
    }
  }

  @Builder settingExitButton(){
    Column() {
      Button($r('app.string.exit_app'), { type: ButtonType.Capsule })
        .buttonStyle(ButtonStyleMode.NORMAL)
        .fontColor(Color.Red)
        .backgroundColor($r('app.color.normal_background_transparent'))
        .backgroundBlurStyle(BlurStyle.BACKGROUND_REGULAR, {
          colorMode: ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 0.1
        })
        .width('100%')
        .margin({ bottom: 15 })
        .onClick(() => {
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          context.terminateSelf((err) => {
            if (!err) {
              context.getApplicationContext().killAllProcesses().catch((error: Error) => {
                console.error(`Quitting ERROR: [${error.name}] ${error.message}`);
              })
            }
          })
        })
    }
    .width('80%')
    .justifyContent(FlexAlign.End)
    .hitTestBehavior(HitTestMode.Transparent);
  }

  /**
   * Tabs 主控程序
   */
  pageInfo: NavPathStack = new NavPathStack();
  @StorageLink('isSplit') isSplit: NavigationMode = NavigationMode.Auto;

  build() {
    Column() {
      Navigation(this.pageInfo) {
        Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
          /**
           * Tab: 首页
           */
          TabContent() {
            this.pageStart()
          }
          .padding({ left: 7, right: 7 })
          .backgroundColor(BackgroundImage.showImage ? undefined : $r('app.color.normal_background'))
          .tabBar(this.tabBuilder($r('app.string.page_start'), 0, $r('app.media.tab0_selected'), $r('app.media.tab0_unselected')))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

          /**
           * Tab: 功能
           */
          TabContent() {
            this.pageFunction()
          }
          .padding({ left: 7, right: 7 })
          .backgroundColor(BackgroundImage.showImage ? undefined : $r('app.color.normal_background'))
          .tabBar(this.tabBuilder($r('app.string.page_function'), 1, $r('app.media.tab1_selected'), $r('app.media.tab1_unselected')))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

          /**
           * Tab: 设置
           */
          TabContent() {
            this.pageSettings()
          }
          .padding({ left: 7, right: 7 })
          .backgroundColor(BackgroundImage.showImage ? undefined : $r('app.color.normal_background'))
          .tabBar(this.tabBuilder($r('app.string.page_settings'), 2, $r('app.media.tab2_selected'),
            $r('app.media.tab2_unselected')))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        }
        .barBackgroundColor(BackgroundImage.blurLevel === undefined ? $r('app.color.shaded_background' + BackgroundImage.themeColor.toString()) : undefined)
        .barBackgroundBlurStyle(BackgroundImage.blurLevel)
        .barHeight('auto')
        .barWidth('100%')
        .vertical(false)
        .barPosition(BarPosition.End)
        .barMode(BarMode.Fixed)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onAnimationStart((_index: number, targetIndex: number) => {
          this.currentIndex = targetIndex;
        })
      }
      .enableDragBar(true)
      .backgroundColor('#00d00721')
      .opacity(BackgroundImage.opacityLevel)
      .navBarWidth('360vp')
      .navBarWidthRange(['336vp', '50%'])
      .hideTitleBar(true)
      .hideToolBar(true)
      .mode(UnifiedPreferences.getNumberSync('AdaptSplit', NavigationMode.Auto))
      .onNavigationModeChange((mode: NavigationMode) => {
        this.isSplit = mode;
      })
    }
    .height('100%')
    .width('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.normal_background'))
    .backgroundImage(BackgroundImage.pic)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
  }
}
